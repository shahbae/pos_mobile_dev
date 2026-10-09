import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_variant_model.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/data/models/topping_model.dart';
import 'package:pos_mobile/data/models/plastic_model.dart';
import 'package:pos_mobile/data/models/sedotan_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';

/// Topping terpilih pada satu baris cart (menyimpan harga untuk kalkulasi).
class CartTopping {
  final Topping topping;
  final int qty;

  CartTopping({required this.topping, this.qty = 1});

  int get lineTotal => topping.price * qty;

  ToppingSelection toSelection() => ToppingSelection(toppingId: topping.id, qty: qty);
}

class CartItem {
  /// Id unik baris — satu produk bisa muncul beberapa baris dengan topping berbeda.
  final int lineId;
  final Product product;
  final ProductVariant? variant; // null = produk tanpa variant (behavior lama)
  final int quantity;
  /// Berapa gelas dari [quantity] yang dituang ke tumbler bawaan pembeli.
  /// Selalu 0..quantity — lihat [ProductTransactionNotifier.setTumblerQty].
  final int tumblerQty;
  final List<CartTopping> freeToppings; // gratis, tidak menambah subtotal
  final List<CartTopping> extraToppings; // berbayar

  CartItem({
    required this.lineId,
    required this.product,
    this.variant,
    required this.quantity,
    this.tumblerQty = 0,
    this.freeToppings = const [],
    this.extraToppings = const [],
  });

  CartItem copyWith({
    int? quantity,
    int? tumblerQty,
    List<CartTopping>? freeToppings,
    List<CartTopping>? extraToppings,
  }) {
    final nextQuantity = quantity ?? this.quantity;
    // Menurunkan qty tidak boleh meninggalkan tumbler yang lebih banyak dari
    // gelasnya — BE menolak transaksi seperti itu.
    final nextTumbler = (tumblerQty ?? this.tumblerQty).clamp(0, nextQuantity);
    return CartItem(
      lineId: lineId,
      product: product,
      variant: variant,
      quantity: nextQuantity,
      tumblerQty: nextTumbler,
      freeToppings: freeToppings ?? this.freeToppings,
      extraToppings: extraToppings ?? this.extraToppings,
    );
  }

  bool get hasToppings => freeToppings.isNotEmpty || extraToppings.isNotEmpty;

  /// Harga satuan yang dipakai: harga variant bila ada, kalau tidak harga produk.
  num get unitPrice => variant?.sellingPriceNum ?? product.sellingPriceNum;

  /// Nama tampilan: "Produk - Variant" bila ada variant.
  String get displayName =>
      variant != null ? '${product.name} - ${variant!.name}' : product.name;

  int get extraToppingTotal => extraToppings.fold(0, (s, t) => s + t.lineTotal);

  /// (harga variant/produk + extra topping) × qty
  num get subtotal => (unitPrice + extraToppingTotal) * quantity;

  TransactionItem toTransactionItem() => TransactionItem(
        productId: product.id,
        variantId: variant?.id,
        quantity: quantity,
        tumblerQty: tumblerQty,
        freeToppings: freeToppings.map((t) => t.toSelection()).toList(),
        extraToppings: extraToppings.map((t) => t.toSelection()).toList(),
      );
}

/// Item gratis = item TAMBAHAN (bonus) di atas item yang dibayar. Boleh menu
/// apa pun yang `freeable`, tidak harus ada di keranjang — keranjang hanya
/// menentukan batas harganya: bonus tidak boleh lebih mahal dari item termurah
/// yang dibeli. Dikirim sebagai baris tambahan di items[] + didaftarkan di
/// promo_free_items agar dipotong jadi 0.
/// qty_dibayar (dasar kuota) = jumlah item yang dibayar, TIDAK termasuk bonus.
class PromoFreeSelection {
  final Product product;
  final ProductVariant? variant; // null = produk tanpa variant
  final int qty; // jumlah yang digratiskan

  PromoFreeSelection({
    required this.product,
    this.variant,
    required this.qty,
  });

  /// Kunci unik per produk+varian (satu baris bonus per kombinasi).
  String get key => '${product.id}_${variant?.id ?? 0}';

  /// Harga satuan yang dipotong (harga variant bila ada, kalau tidak harga produk).
  num get unitPrice => variant?.sellingPriceNum ?? product.sellingPriceNum;

  /// Nama tampilan: "Produk - Variant" bila ada variant.
  String get displayName =>
      variant != null ? '${product.name} - ${variant!.name}' : product.name;

  /// Nilai yang dipotong promo (harga × qty gratis).
  num get discountValue => unitPrice * qty;

  PromoFreeSelection copyWith({int? qty}) => PromoFreeSelection(
        product: product,
        variant: variant,
        qty: qty ?? this.qty,
      );
}

/// Plastik/kemasan terpilih untuk seluruh transaksi (bukan per item).
class CartPlastic {
  final Plastic plastic;
  final int qty;

  CartPlastic({required this.plastic, this.qty = 1});

  PlasticSelection toSelection() => PlasticSelection(plasticId: plastic.id, qty: qty);
}

/// Sedotan terpilih untuk seluruh transaksi (bukan per item).
class CartSedotan {
  final Sedotan sedotan;
  final int qty;

  CartSedotan({required this.sedotan, this.qty = 1});

  SedotanSelection toSelection() => SedotanSelection(sedotanId: sedotan.id, qty: qty);
}

/// Jumlah gelas yang jadi dasar sedotan otomatis untuk sebuah [autoFor]:
/// gelas di baris bertopping untuk `with_topping`, sisanya (termasuk bonus
/// promo, yang tak pernah membawa topping) untuk `without_topping`. Gelas
/// yang dituang ke tumbler tidak dihitung: pembeli bertumbler tidak mengambil
/// sedotan. Kalau ia tetap minta, kasir menambah angkanya sendiri.
int sedotanAutoQty(ProductTransactionState state, String autoFor) {
  int glasses(CartItem i) => i.quantity - i.tumblerQty;
  switch (autoFor) {
    case SedotanAutoFor.withTopping:
      return state.items.where((i) => i.hasToppings).fold(0, (s, i) => s + glasses(i));
    case SedotanAutoFor.withoutTopping:
      return state.items.where((i) => !i.hasToppings).fold(0, (s, i) => s + glasses(i)) +
          state.selectedFreeQty;
    default:
      return 0;
  }
}

class ProductTransactionState {
  final List<CartItem> items;
  final Promo? selectedPromo;
  final List<PromoFreeSelection> promoFreeItems;
  final List<CartPlastic> plastics;
  final List<CartSedotan> sedotans;

  /// sedotan_id yang angkanya sudah diubah kasir. Sedotan ini tidak lagi diisi
  /// otomatis sampai transaksi selesai (state baru = set kosong).
  final Set<int> manualSedotanIds;
  final bool isLoading;
  final String? error;
  final ProductTransactionResponse? lastResponse;

  ProductTransactionState({
    this.items = const [],
    this.selectedPromo,
    this.promoFreeItems = const [],
    this.plastics = const [],
    this.sedotans = const [],
    this.manualSedotanIds = const {},
    this.isLoading = false,
    this.error,
    this.lastResponse,
  });

  /// Subtotal item yang DIBAYAR (cart items). Bonus gratis tidak termasuk.
  num get paidSubtotal => items.fold(0, (sum, item) => sum + item.subtotal);

  /// Subtotal kotor untuk struk: item dibayar + nilai item gratis (bonus).
  num get subtotal => paidSubtotal + promoDiscount;

  /// Jumlah item yang dibayar — dasar kuota promo (qty_dibayar di BE).
  /// Bonus gratis dikirim terpisah, jadi tidak mengurangi angka ini.
  int get paidQty => items.fold(0, (sum, item) => sum + item.quantity);

  /// Total nilai item gratis (bonus) yang dipotong promo.
  num get promoDiscount => promoFreeItems.fold(0, (sum, p) => sum + p.discountValue);

  /// Jumlah item gratis (bonus) yang sudah dipilih.
  int get selectedFreeQty => promoFreeItems.fold(0, (s, p) => s + p.qty);

  /// Total akhir = item dibayar saja (bonus gratis dipotong jadi 0).
  num get total => paidSubtotal.clamp(0, double.infinity);

  ProductTransactionState copyWith({
    List<CartItem>? items,
    Promo? selectedPromo,
    bool clearPromo = false,
    List<PromoFreeSelection>? promoFreeItems,
    List<CartPlastic>? plastics,
    List<CartSedotan>? sedotans,
    Set<int>? manualSedotanIds,
    bool? isLoading,
    String? error,
    ProductTransactionResponse? lastResponse,
    bool clearLastResponse = false,
  }) {
    return ProductTransactionState(
      items: items ?? this.items,
      selectedPromo: clearPromo ? null : (selectedPromo ?? this.selectedPromo),
      promoFreeItems: promoFreeItems ?? this.promoFreeItems,
      plastics: plastics ?? this.plastics,
      sedotans: sedotans ?? this.sedotans,
      manualSedotanIds: manualSedotanIds ?? this.manualSedotanIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastResponse: clearLastResponse ? null : (lastResponse ?? this.lastResponse),
    );
  }
}

final productTransactionProvider =
    StateNotifierProvider.autoDispose<ProductTransactionNotifier, ProductTransactionState>((ref) {
  final repo = ref.watch(productTransactionRepositoryProvider);
  return ProductTransactionNotifier(repo);
});

class ProductTransactionNotifier extends StateNotifier<ProductTransactionState> {
  final ProductTransactionRepository repo;
  int _lineCounter = 0;

  /// Master sedotan aktif, diberikan halaman checkout. Kosong = belum dimuat,
  /// sedotan otomatis belum bisa diisi.
  List<Sedotan> _sedotanMasters = const [];

  /// Idempotency key percobaan bayar yang hasilnya belum pasti, dan isi
  /// keranjang saat key itu dibuat. Null = percobaan berikutnya memulai
  /// transaksi baru. Lihat [_attemptKeyFor].
  String? _attemptKey;
  String? _attemptCart;

  /// true selama semua percobaan dengan [_attemptKey] adalah QRIS yang
  /// menghasilkan QR, jadi paling jauh yang tercatat di server adalah QR yang
  /// belum dibayar — bukan penjualan lunas.
  bool _attemptOnlyQr = false;

  ProductTransactionNotifier(this.repo) : super(ProductTransactionState());

  int _nextLineId() => ++_lineCounter;

  /// Tambah produk tanpa topping — digabung ke baris polos yang sudah ada
  /// (produk + variant sama). Variant berbeda = baris terpisah.
  void addToCart(Product product, {ProductVariant? variant}) {
    final idx = state.items.indexWhere(
      (i) => i.product.id == product.id && i.variant?.id == variant?.id && !i.hasToppings,
    );
    if (idx != -1) {
      final updated = List<CartItem>.from(state.items);
      updated[idx] = updated[idx].copyWith(quantity: updated[idx].quantity + 1);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        CartItem(lineId: _nextLineId(), product: product, variant: variant, quantity: 1),
      ]);
    }
    _syncAutoSedotans();
  }

  /// Tambah baris baru dengan topping (selalu baris terpisah).
  void addLineWithToppings(
    Product product, {
    ProductVariant? variant,
    int quantity = 1,
    List<CartTopping> freeToppings = const [],
    List<CartTopping> extraToppings = const [],
  }) {
    state = state.copyWith(items: [
      ...state.items,
      CartItem(
        lineId: _nextLineId(),
        product: product,
        variant: variant,
        quantity: quantity,
        freeToppings: freeToppings,
        extraToppings: extraToppings,
      ),
    ]);
    _syncAutoSedotans();
  }

  void updateLineToppings(
    int lineId, {
    required List<CartTopping> freeToppings,
    required List<CartTopping> extraToppings,
  }) {
    final updated = state.items
        .map((i) => i.lineId == lineId
            ? i.copyWith(freeToppings: freeToppings, extraToppings: extraToppings)
            : i)
        .toList();
    state = state.copyWith(items: updated);
    _syncAutoSedotans();
  }

  void removeLine(int lineId) {
    state = state.copyWith(
      items: state.items.where((i) => i.lineId != lineId).toList(),
    );
    _reconcilePromo();
    _syncAutoSedotans();
  }

  void updateQuantity(int lineId, int quantity) {
    if (quantity <= 0) {
      removeLine(lineId);
      return;
    }
    final updated = state.items
        .map((i) => i.lineId == lineId ? i.copyWith(quantity: quantity) : i)
        .toList();
    state = state.copyWith(items: updated);
    _reconcilePromo();
    _syncAutoSedotans();
  }

  /// Set berapa gelas pada satu baris yang dituang ke tumbler pembeli.
  /// Dibatasi 0..qty baris itu; BE menolak nilai di luar rentang tersebut.
  void setTumblerQty(int lineId, int tumblerQty) {
    final updated = state.items
        .map((i) => i.lineId == lineId ? i.copyWith(tumblerQty: tumblerQty) : i)
        .toList();
    state = state.copyWith(items: updated);
    _syncAutoSedotans();
  }

  void clearCart() {
    _dropAttemptKey();
    state = ProductTransactionState();
  }

  // ── Plastik / kemasan ─────────────────────────────────
  /// Set jumlah plastik untuk sebuah master plastik (0 = hapus dari transaksi).
  void setPlastic(Plastic plastic, {required int qty}) {
    final list = state.plastics.where((p) => p.plastic.id != plastic.id).toList();
    if (qty > 0) list.add(CartPlastic(plastic: plastic, qty: qty));
    state = state.copyWith(plastics: list);
  }

  void removePlastic(int plasticId) {
    state = state.copyWith(
      plastics: state.plastics.where((p) => p.plastic.id != plasticId).toList(),
    );
  }

  // ── Sedotan ───────────────────────────────────────────
  /// Set jumlah sedotan untuk sebuah master sedotan (0 = hapus dari transaksi).
  /// Dipanggil saat kasir mengubah angka, jadi sedotan ini berhenti diisi
  /// otomatis — termasuk kalau sengaja dinolkan (pembeli tak mau sedotan).
  void setSedotan(Sedotan sedotan, {required int qty}) {
    final list = state.sedotans.where((s) => s.sedotan.id != sedotan.id).toList();
    if (qty > 0) list.add(CartSedotan(sedotan: sedotan, qty: qty));
    state = state.copyWith(
      sedotans: list,
      manualSedotanIds: {...state.manualSedotanIds, sedotan.id},
    );
  }

  /// Terima daftar master sedotan dari halaman checkout, lalu isi ulang
  /// sedotan otomatis dari keranjang saat ini.
  void setSedotanMasters(List<Sedotan> sedotans) {
    _sedotanMasters = sedotans;
    _syncAutoSedotans();
  }

  /// Isi jumlah sedotan bertanda auto_for dari keranjang. Sedotan yang sudah
  /// diubah kasir dan sedotan manual (none) dibiarkan apa adanya. Dipanggil
  /// setiap baris atau bonus promo berubah.
  void _syncAutoSedotans() {
    final auto = _sedotanMasters.where((s) =>
        s.autoFor != SedotanAutoFor.none && !state.manualSedotanIds.contains(s.id));
    if (auto.isEmpty) return;
    final autoIds = {for (final s in auto) s.id};
    final list = state.sedotans.where((cs) => !autoIds.contains(cs.sedotan.id)).toList();
    for (final s in auto) {
      final qty = sedotanAutoQty(state, s.autoFor);
      if (qty > 0) list.add(CartSedotan(sedotan: s, qty: qty));
    }
    state = state.copyWith(sedotans: list);
  }

  void removeSedotan(int sedotanId) {
    state = state.copyWith(
      sedotans: state.sedotans.where((s) => s.sedotan.id != sedotanId).toList(),
    );
  }

  // ── Promo ──────────────────────────────────────────────
  void selectPromo(Promo? promo) {
    if (promo == null) {
      state = state.copyWith(clearPromo: true, promoFreeItems: []);
    } else {
      state = state.copyWith(selectedPromo: promo);
      _reconcilePromo();
    }
    _syncAutoSedotans();
  }

  /// Set jumlah bonus gratis untuk sebuah produk+varian (0 = hapus).
  /// Produk boleh apa pun yang freeable, tidak harus ada di keranjang.
  void setPromoFreeItem(Product product, {ProductVariant? variant, required int qty}) {
    final selKey = '${product.id}_${variant?.id ?? 0}';
    final list = state.promoFreeItems.where((p) => p.key != selKey).toList();
    if (qty > 0) {
      list.add(PromoFreeSelection(product: product, variant: variant, qty: qty));
    }
    state = state.copyWith(promoFreeItems: list);
    _reconcilePromo();
    _syncAutoSedotans();
  }

  void removePromoFreeItem(String key) {
    state = state.copyWith(
      promoFreeItems: state.promoFreeItems.where((p) => p.key != key).toList(),
    );
    _syncAutoSedotans();
  }

  /// Pastikan total item gratis (bonus) tidak melebihi kuota promo dari
  /// jumlah item yang dibayar. Dipanggil ulang saat keranjang/promo berubah.
  void _reconcilePromo() {
    final promo = state.selectedPromo;
    if (promo == null || state.promoFreeItems.isEmpty) return;

    final maxFree = promo.maxFreeQty(state.paidQty);

    int remaining = maxFree;
    final reconciled = <PromoFreeSelection>[];
    for (final p in state.promoFreeItems) {
      final allowed = min(p.qty, remaining);
      if (allowed > 0) {
        reconciled.add(p.copyWith(qty: allowed));
        remaining -= allowed;
      }
    }
    state = state.copyWith(promoFreeItems: reconciled);
  }

  /// Bangun payload transaksi dari state keranjang saat ini.
  ProductTransactionRequest _buildRequest({
    required String paymentMethod,
    required int paid,
    int discount = 0,
    String? paymentRef,
    String? customerName,
  }) {
    final promo = state.selectedPromo;
    final freeSelections = (promo == null) ? const <PromoFreeSelection>[] : state.promoFreeItems;

    // Bonus gratis dikirim sebagai baris TAMBAHAN di items[] (agar product_id
    // ada di order, syarat BE) lalu didaftarkan di promo_free_items supaya
    // harganya dipotong jadi 0. Bonus tidak membawa extra topping.
    final promoFreeItems = freeSelections
        .map((p) => PromoFreeItem(
              promoId: promo!.id,
              productId: p.product.id,
              variantId: p.variant?.id,
              qty: p.qty,
            ))
        .toList();

    final items = [
      ...state.items.map((i) => i.toTransactionItem()),
      ...freeSelections.map((p) => TransactionItem(
            productId: p.product.id,
            variantId: p.variant?.id,
            quantity: p.qty,
          )),
    ];

    final plastics = state.plastics.map((p) => p.toSelection()).toList();
    final sedotans = state.sedotans.map((s) => s.toSelection()).toList();

    // Yang menentukan stok dan total. Metode bayar, nominal, dan nama pembeli
    // sengaja tidak ikut: mengubahnya bukan berarti pesanannya lain.
    final cart = jsonEncode({
      'items': items.map((i) => i.toJson()).toList(),
      'promo_free_items': promoFreeItems.map((p) => p.toJson()).toList(),
      'plastics': plastics.map((p) => p.toJson()).toList(),
      'sedotans': sedotans.map((s) => s.toJson()).toList(),
      'discount': discount,
    });
    // QRIS senilai Rp0 langsung dicatat lunas oleh server, tanpa QR.
    final makesQr = paymentMethod.toLowerCase() == 'qris' && state.total > 0;

    return ProductTransactionRequest(
      items: items,
      promoFreeItems: promoFreeItems,
      plastics: plastics,
      sedotans: sedotans,
      paymentMethod: paymentMethod,
      paid: paid,
      discount: discount,
      paymentRef: paymentRef,
      customerName: customerName,
      idempotencyKey: _attemptKeyFor(cart, makesQr: makesQr),
    );
  }

  /// Idempotency key untuk percobaan bayar ini.
  ///
  /// Satu key dipakai untuk semua percobaan atas keranjang yang sama selama
  /// hasilnya belum pasti: permintaan yang sampai ke server tapi jawabannya
  /// hilang akan dibalas server dengan transaksi yang sudah tercatat, bukan
  /// dicatat sekali lagi. Key diganti kalau isi keranjang berubah, atau begitu
  /// server menjawab (lihat [_dropAttemptKey]).
  String _attemptKeyFor(String cart, {required bool makesQr}) {
    // Percobaan sebelumnya paling jauh meninggalkan QR yang belum dibayar, dan
    // QR tidak bisa dilunasi dengan tunai. Mulai transaksi baru; QR lama
    // kedaluwarsa sendiri dan stoknya dikembalikan server.
    final abandonsQr = _attemptOnlyQr && !makesQr;
    if (_attemptKey == null || _attemptCart != cart || abandonsQr) {
      _attemptKey = _genIdempotencyKey();
      _attemptCart = cart;
      _attemptOnlyQr = makesQr;
    } else {
      _attemptOnlyQr = _attemptOnlyQr && makesQr;
    }
    return _attemptKey!;
  }

  /// Hasil percobaan sudah pasti — tercatat, atau ditolak server — jadi
  /// percobaan berikutnya adalah transaksi baru.
  void _dropAttemptKey() {
    _attemptKey = null;
    _attemptCart = null;
    _attemptOnlyQr = false;
  }

  /// Galat tanpa kepastian (timeout, koneksi putus, 5xx) membiarkan key tetap
  /// dipakai; hanya penolakan yang jelas dari server yang melepasnya.
  void _dropAttemptKeyIfRejected(Object error) {
    if (error is TransactionSubmitException && error.rejected) _dropAttemptKey();
  }

  Future<void> submitTransaction({
    required String paymentMethod,
    required int paid,
    int discount = 0,
    String? paymentRef,
    String? customerName,
  }) async {
    if (state.items.isEmpty) return;

    // `lastResponse` WAJIB dibersihkan di awal: halaman checkout memutuskan
    // sukses/gagal dari field ini, dan notifier ini hidup terus selama kasir
    // tidak meninggalkan halaman POS. Kalau invoice transaksi sebelumnya
    // tertinggal, submit yang GAGAL akan tetap membuka halaman "Transaksi
    // Berhasil" dengan invoice lama — dan struk lama tercetak dua kali.
    state = state.copyWith(isLoading: true, error: null, clearLastResponse: true);

    final request = _buildRequest(
      paymentMethod: paymentMethod,
      paid: paid,
      discount: discount,
      paymentRef: paymentRef,
      customerName: customerName,
    );

    try {
      final response = await repo.createTransaction(request);
      _dropAttemptKey();
      state = ProductTransactionState(lastResponse: response); // reset cart on success
    } catch (e) {
      _dropAttemptKeyIfRejected(e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Charge QRIS. Keranjang TIDAK direset di sini — hanya direset saat sudah
  /// lunas (dari QR page) supaya bisa retry bila QR kedaluwarsa/dibatalkan.
  /// Return hasil (pending QR / langsung lunas), atau null bila gagal (lihat state.error).
  Future<QrisChargeResult?> chargeQris({
    int discount = 0,
    String? customerName,
  }) async {
    if (state.items.isEmpty) return null;

    state = state.copyWith(isLoading: true, error: null);

    // QRIS: payment_method lowercase "qris", paid = total (BE tetap validasi paid).
    final request = _buildRequest(
      paymentMethod: 'qris',
      paid: state.total.toInt(),
      discount: discount,
      customerName: customerName,
    );

    try {
      final result = await repo.createQrisTransaction(request);
      _dropAttemptKey();
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      _dropAttemptKeyIfRejected(e);
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  String _genIdempotencyKey() {
    final rnd = Random();
    String seg(int n) =>
        List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${seg(8)}-${seg(4)}-4${seg(3)}-${seg(4)}-${seg(12)}';
  }
}
