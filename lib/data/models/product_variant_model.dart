/// Variasi/ukuran sebuah produk (mis. "Hot S", "Ice M").
///
/// Sumber: GET /products/:id/variants. Setiap variant punya harga jual sendiri;
/// harga inilah yang dipakai di POS (bukan harga produk) bila variant dipilih.
class ProductVariant {
  final int id;
  final int productId;
  final String name;
  final String sellingPrice;

  /// Jumlah slot topping gratis untuk variant ini. Bila baris item memakai
  /// variant, angka inilah yang dipakai (bukan slot produk). Default 0 →
  /// variant lama tidak mengizinkan topping gratis sampai owner set nilainya.
  final int freeToppingSlots;

  final bool isActive;

  /// Kesiapan stok varian di cabang aktif (dari GET /products, branch-scoped).
  /// `true` = bahan cukup, `false` = habis, `null` = tak dihitung (view lintas
  /// cabang / endpoint tanpa konteks cabang). `null` diperlakukan "boleh dijual".
  final bool? isReady;

  /// Override waktu pembuatan milik varian ini (menit, 0–240).
  /// `null` = ikut produk induk — bedakan dari angka yang kebetulan sama.
  final int? prepMinutes;

  /// Hasil akhir yang dipakai BE untuk estimasi: override varian bila ada,
  /// kalau tidak nilai produk. Null bila BE tidak mengirimnya (endpoint lama).
  final int? effectivePrepMinutes;

  final String? createdAt;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    required this.sellingPrice,
    this.freeToppingSlots = 0,
    this.isActive = true,
    this.isReady,
    this.prepMinutes,
    this.effectivePrepMinutes,
    this.createdAt,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> j) {
    return ProductVariant(
      id: j['id'],
      productId: (j['product_id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      sellingPrice: j['selling_price']?.toString() ?? '0',
      freeToppingSlots: (j['free_topping_slots'] as num?)?.toInt() ?? 0,
      isActive: j['is_active'] as bool? ?? true,
      isReady: j['is_ready'] as bool?,
      prepMinutes: (j['prep_minutes'] as num?)?.toInt(),
      effectivePrepMinutes: (j['effective_prep_minutes'] as num?)?.toInt(),
      createdAt: j['created_at']?.toString(),
    );
  }

  /// Varian boleh dipesan bila belum habis. `null` (tak dihitung) = boleh.
  bool get ready => isReady != false;

  num get sellingPriceNum => num.tryParse(sellingPrice) ?? 0;

  /// Waktu pembuatan yang berlaku untuk varian ini: `effective_prep_minutes`
  /// dari BE bila dikirim, kalau tidak override varian, terakhir nilai produk.
  int effectivePrepFor(int productPrepMinutes) =>
      effectivePrepMinutes ?? prepMinutes ?? productPrepMinutes;

  /// Variant mengizinkan topping gratis bila punya slot > 0.
  bool get hasFreeToppings => freeToppingSlots > 0;
}
