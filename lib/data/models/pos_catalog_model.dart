import 'dart:convert';

import 'package:pos_mobile/data/local/catalog_store.dart';
import 'package:pos_mobile/data/models/plastic_model.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_variant_model.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/data/models/sedotan_model.dart';
import 'package:pos_mobile/data/models/topping_model.dart';

/// Nomor bentuk isi katalog yang dipahami versi aplikasi ini.
///
/// Naikkan setiap cara membaca isi katalog berubah (field baru yang wajib,
/// arti field berubah). Potret lama di HP lalu dibuang dan diunduh ulang,
/// alih-alih dibaca dengan cara yang salah.
const posCatalogSchema = 1;

/// Info toko untuk kepala nota.
class PosCatalogStoreInfo {
  final String name;
  final String address;
  final String footerNote;
  final String complaintNote;

  const PosCatalogStoreInfo({
    this.name = '',
    this.address = '',
    this.footerNote = '',
    this.complaintNote = '',
  });

  factory PosCatalogStoreInfo.fromJson(Map<String, dynamic> j) => PosCatalogStoreInfo(
        name: j['name']?.toString() ?? '',
        address: j['address']?.toString() ?? '',
        footerNote: j['footer_note']?.toString() ?? '',
        complaintNote: j['complaint_note']?.toString() ?? '',
      );
}

/// Seluruh bahan kerja kasir: menu, harga, kemasan, dan promo cabang ini,
/// sebagaimana dikirim `GET /pos/catalog`.
///
/// Dipakai untuk menampilkan dan menghitung di layar. Selama jualan masih
/// online, angka resminya tetap dari server saat bayar.
class PosCatalog {
  /// Sidik jari isi dari server. Dua katalog berversi sama isinya sama.
  final String version;

  /// Kapan isi ini diunduh dari server (jam HP).
  final DateTime fetchedAt;

  final bool offlineSalesEnabled;
  final PosCatalogStoreInfo store;

  /// Semua produk beserta varian aktifnya.
  final List<Product> products;

  /// Hanya yang aktif. Yang nonaktif tetap dikirim server, tetapi kasir tidak
  /// pernah boleh memilihnya.
  final List<Topping> toppings;
  final List<Plastic> plastics;
  final List<Sedotan> sedotans;

  /// Promo aktif dengan SEMUA harinya; pakai [promosOn] untuk hari tertentu.
  final List<Promo> promos;

  final Map<int, List<Promo>> _promosByDay = {};

  PosCatalog({
    required this.version,
    required this.fetchedAt,
    required this.offlineSalesEnabled,
    required this.store,
    required this.products,
    required this.toppings,
    required this.plastics,
    required this.sedotans,
    required this.promos,
  });

  /// Baca isi katalog. Melempar bila bentuknya tidak seperti yang diharapkan —
  /// pemanggil menganggap itu potret rusak, bukan katalog kosong.
  factory PosCatalog.fromContent(
    Map<String, dynamic> j, {
    required String version,
    required DateTime fetchedAt,
  }) {
    List<Map<String, dynamic>> list(String key) =>
        (j[key] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return PosCatalog(
      version: version,
      fetchedAt: fetchedAt,
      offlineSalesEnabled: j['offline_sales_enabled'] == true,
      store: PosCatalogStoreInfo.fromJson(Map<String, dynamic>.from(j['store'] as Map)),
      products: list('products').map(_product).toList(),
      toppings: list('toppings').map(Topping.fromJson).where((t) => t.isActive).toList(),
      plastics: list('plastics').map(Plastic.fromJson).where((p) => p.isActive).toList(),
      sedotans: list('sedotans').map(Sedotan.fromJson).where((s) => s.isActive).toList(),
      promos: list('promos').map(Promo.fromJson).where((p) => p.isActive).toList(),
    );
  }

  /// Baca potret dari penyimpanan lokal.
  factory PosCatalog.fromStored(StoredCatalog stored) => PosCatalog.fromContent(
        Map<String, dynamic>.from(jsonDecode(stored.payload) as Map),
        version: stored.version,
        fetchedAt: stored.fetchedAt,
      );

  /// Promo yang berlaku pada hari [beWeekday] (konvensi server: 0=Minggu …
  /// 6=Sabtu). Hasilnya diingat per hari, jadi pemanggilan berulang
  /// mengembalikan daftar yang sama persis.
  List<Promo> promosOn(int beWeekday) =>
      _promosByDay[beWeekday] ??= promos.where((p) => p.days.contains(beWeekday)).toList();

  /// Promo yang berlaku hari ini menurut jam HP.
  List<Promo> get promosToday => promosOn(DateTime.now().weekday % 7);
}

/// Varian di dalam daftar produk dikirim tanpa `product_id`; diisi dari
/// produk induknya supaya varian dari katalog sama lengkapnya dengan varian
/// dari `GET /products/:id/variants`.
Product _product(Map<String, dynamic> j) {
  final p = Product.fromJson(j);
  if (p.variants.every((v) => v.productId == p.id)) return p;
  return Product(
    id: p.id,
    tenantId: p.tenantId,
    sku: p.sku,
    name: p.name,
    imageUrl: p.imageUrl,
    categoryId: p.categoryId,
    categoryName: p.categoryName,
    categoryFreeable: p.categoryFreeable,
    purchasePrice: p.purchasePrice,
    sellingPrice: p.sellingPrice,
    profitMargin: p.profitMargin,
    freeToppingSlots: p.freeToppingSlots,
    hasFreeToppings: p.hasFreeToppings,
    hasVariants: p.hasVariants,
    variants: [
      for (final v in p.variants)
        ProductVariant(
          id: v.id,
          productId: p.id,
          name: v.name,
          sellingPrice: v.sellingPrice,
          freeToppingSlots: v.freeToppingSlots,
          isActive: v.isActive,
          isReady: v.isReady,
          prepMinutes: v.prepMinutes,
          effectivePrepMinutes: v.effectivePrepMinutes,
          createdAt: v.createdAt,
        ),
    ],
    productReady: p.productReady,
    prepMinutes: p.prepMinutes,
    createdAt: p.createdAt,
  );
}

/// Shift yang sedang terbuka di cabang, menurut server saat katalog diminta.
class PosCatalogShift {
  final int id;
  final String name;
  final String date;

  /// Nomor antrean terakhir yang sudah diberikan di shift ini.
  final int lastQueueNo;

  const PosCatalogShift({
    required this.id,
    required this.name,
    required this.date,
    required this.lastQueueNo,
  });

  factory PosCatalogShift.fromJson(Map<String, dynamic> j) => PosCatalogShift(
        id: (j['id'] as num).toInt(),
        name: j['shift_name']?.toString() ?? '',
        date: j['shift_date']?.toString() ?? '',
        lastQueueNo: (j['last_queue_no'] as num?)?.toInt() ?? 0,
      );
}

/// Satu jawaban `GET /pos/catalog`.
class PosCatalogFetch {
  final String version;

  /// true = versi yang dikirim masih berlaku; [catalog] dan [stored] kosong.
  final bool unchanged;
  final DateTime? serverTime;

  /// Jam HP saat jawaban ini diterima.
  final DateTime receivedAt;

  /// null bila cabang belum membuka shift.
  final PosCatalogShift? shift;

  /// Kasir yang sedang login, menurut server.
  final int cashierId;
  final String cashierName;

  final PosCatalog? catalog;

  /// Isi yang sama dalam bentuk siap simpan.
  final StoredCatalog? stored;

  const PosCatalogFetch({
    required this.version,
    required this.unchanged,
    required this.receivedAt,
    this.serverTime,
    this.shift,
    this.cashierId = 0,
    this.cashierName = '',
    this.catalog,
    this.stored,
  });

  /// Seberapa jauh jam server di depan jam HP (negatif = HP lebih maju). null
  /// bila server tidak mengirim jamnya.
  Duration? get clockOffset => serverTime?.difference(receivedAt);

  /// Baca `data` dari jawaban server. [fetchedAt] adalah jam HP saat jawaban
  /// diterima.
  factory PosCatalogFetch.fromJson(Map<String, dynamic> data, {required DateTime fetchedAt}) {
    final version = data['version']?.toString() ?? '';
    final unchanged = data['unchanged'] == true;
    final shift = data['shift'];
    final serverTime = DateTime.tryParse(data['server_time']?.toString() ?? '');
    final cashier = data['cashier'];
    final cashierId = cashier is Map ? (cashier['id'] as num?)?.toInt() ?? 0 : 0;
    final cashierName = cashier is Map ? cashier['name']?.toString() ?? '' : '';

    if (unchanged) {
      return PosCatalogFetch(
        version: version,
        unchanged: true,
        receivedAt: fetchedAt,
        serverTime: serverTime,
        shift: shift is Map ? PosCatalogShift.fromJson(Map<String, dynamic>.from(shift)) : null,
        cashierId: cashierId,
        cashierName: cashierName,
      );
    }

    // Yang disimpan hanya isi katalog. Jam server, kasir, dan shift berubah
    // sendiri dan tidak ikut menentukan versi.
    final content = <String, dynamic>{
      for (final key in const [
        'store',
        'offline_sales_enabled',
        'products',
        'toppings',
        'plastics',
        'sedotans',
        'promos',
      ])
        key: data[key],
    };
    return PosCatalogFetch(
      version: version,
      unchanged: false,
      receivedAt: fetchedAt,
      serverTime: serverTime,
      shift: shift is Map ? PosCatalogShift.fromJson(Map<String, dynamic>.from(shift)) : null,
      cashierId: cashierId,
      cashierName: cashierName,
      catalog: PosCatalog.fromContent(content, version: version, fetchedAt: fetchedAt),
      stored: StoredCatalog(
        schema: posCatalogSchema,
        version: version,
        fetchedAt: fetchedAt,
        payload: jsonEncode(content),
      ),
    );
  }
}
