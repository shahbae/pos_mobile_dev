import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_variant_model.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/data/models/topping_model.dart';
import 'package:pos_mobile/data/models/plastic_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
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
  final List<CartTopping> freeToppings; // gratis, tidak menambah subtotal
  final List<CartTopping> extraToppings; // berbayar

  CartItem({
    required this.lineId,
    required this.product,
    this.variant,
    required this.quantity,
    this.freeToppings = const [],
    this.extraToppings = const [],
  });

  CartItem copyWith({
    int? quantity,
    List<CartTopping>? freeToppings,
    List<CartTopping>? extraToppings,
  }) {
    return CartItem(
      lineId: lineId,
      product: product,
      variant: variant,
      quantity: quantity ?? this.quantity,
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
        freeToppings: freeToppings.map((t) => t.toSelection()).toList(),
        extraToppings: extraToppings.map((t) => t.toSelection()).toList(),
      );
}

/// Item gratis = item TAMBAHAN (bonus) di atas item yang dibayar. Bisa produk
/// apa pun yang `freeable` (tidak harus ada di keranjang). Dikirim sebagai baris
/// tambahan di items[] + didaftarkan di promo_free_items agar dipotong jadi 0.
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

class ProductTransactionState {
  final List<CartItem> items;
  final Promo? selectedPromo;
  final List<PromoFreeSelection> promoFreeItems;
  final List<CartPlastic> plastics;
  final bool isLoading;
  final String? error;
  final ProductTransactionResponse? lastResponse;

  ProductTransactionState({
    this.items = const [],
    this.selectedPromo,
    this.promoFreeItems = const [],
    this.plastics = const [],
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
    bool? isLoading,
    String? error,
    ProductTransactionResponse? lastResponse,
  }) {
    return ProductTransactionState(
      items: items ?? this.items,
      selectedPromo: clearPromo ? null : (selectedPromo ?? this.selectedPromo),
      promoFreeItems: promoFreeItems ?? this.promoFreeItems,
      plastics: plastics ?? this.plastics,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastResponse: lastResponse ?? this.lastResponse,
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
  }

  void removeLine(int lineId) {
    state = state.copyWith(
      items: state.items.where((i) => i.lineId != lineId).toList(),
    );
    _reconcilePromo();
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
  }

  void clearCart() {
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

  // ── Promo ──────────────────────────────────────────────
  void selectPromo(Promo? promo) {
    if (promo == null) {
      state = state.copyWith(clearPromo: true, promoFreeItems: []);
    } else {
      state = state.copyWith(selectedPromo: promo);
      _reconcilePromo();
    }
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
  }

  void removePromoFreeItem(String key) {
    state = state.copyWith(
      promoFreeItems: state.promoFreeItems.where((p) => p.key != key).toList(),
    );
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

  Future<void> submitTransaction({
    required String paymentMethod,
    required int paid,
    int discount = 0,
    String? paymentRef,
    String? customerName,
  }) async {
    if (state.items.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

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

    final request = ProductTransactionRequest(
      items: items,
      promoFreeItems: promoFreeItems,
      plastics: state.plastics.map((p) => p.toSelection()).toList(),
      paymentMethod: paymentMethod,
      paid: paid,
      discount: discount,
      paymentRef: paymentRef,
      customerName: customerName,
      idempotencyKey: _genIdempotencyKey(),
    );

    try {
      final response = await repo.createTransaction(request);
      state = ProductTransactionState(lastResponse: response); // reset cart on success
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Idempotency key unik per submit (cegah transaksi dobel saat retry).
  String _genIdempotencyKey() {
    final rnd = Random();
    String seg(int n) =>
        List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${seg(8)}-${seg(4)}-4${seg(3)}-${seg(4)}-${seg(12)}';
  }
}
