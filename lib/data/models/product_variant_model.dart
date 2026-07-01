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
  final String? createdAt;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    required this.sellingPrice,
    this.freeToppingSlots = 0,
    this.isActive = true,
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
      createdAt: j['created_at']?.toString(),
    );
  }

  num get sellingPriceNum => num.tryParse(sellingPrice) ?? 0;

  /// Variant mengizinkan topping gratis bila punya slot > 0.
  bool get hasFreeToppings => freeToppingSlots > 0;
}
