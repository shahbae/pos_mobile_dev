import 'package:pos_mobile/data/models/product_variant_model.dart';

class Product {
  final int id;
  final int? tenantId;
  final String? sku;
  final String name;
  final String? imageUrl;
  final int? categoryId;
  final String? categoryName;
  final bool categoryFreeable; // dari category.freeable (default true)
  final String purchasePrice;
  final String sellingPrice;
  final String? profitMargin;
  final int freeToppingSlots;
  final bool hasFreeToppings;
  final bool hasVariants;
  final List<ProductVariant> variants;

  /// Kesiapan stok produk di cabang aktif (dari GET /products, branch-scoped).
  /// `true` = minimal satu varian/produk siap dijual, `false` = habis,
  /// `null` = tak dihitung (view lintas cabang / endpoint tanpa konteks cabang).
  /// `null` diperlakukan "boleh dijual".
  final bool? productReady;

  final String? createdAt;

  Product({
    required this.id,
    this.tenantId,
    this.sku,
    required this.name,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    this.categoryFreeable = true,
    required this.purchasePrice,
    required this.sellingPrice,
    this.profitMargin,
    this.freeToppingSlots = 0,
    this.hasFreeToppings = false,
    this.hasVariants = false,
    this.variants = const [],
    this.productReady,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;
    final slots = (j['free_topping_slots'] as num?)?.toInt() ?? 0;
    final img = j['image_url']?.toString();
    final rawVariants = j['variants'];
    final variants = (rawVariants is List)
        ? rawVariants.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>)).toList()
        : <ProductVariant>[];

    return Product(
      id: j['id'],
      tenantId: j['tenant_id'],
      sku: j['sku'],
      name: j['name'],
      imageUrl: (img == null || img.trim().isEmpty) ? null : img,
      categoryId: cat != null ? cat['id'] : j['category_id'],
      categoryName: cat != null ? cat['name'] : j['category_name'],
      // Hanya kategori freeable yang boleh jadi item gratis promo.
      // Default true bila objek category / field tidak dikirim.
      categoryFreeable: cat == null
          ? true
          : (cat['freeable'] is bool
              ? cat['freeable'] as bool
              : (cat['freeable'] == null
                  ? true
                  : cat['freeable'].toString().toLowerCase() != 'false' &&
                      cat['freeable'].toString() != '0')),
      purchasePrice: j['purchase_price']?.toString() ?? '0',
      sellingPrice: j['selling_price']?.toString() ?? '0',
      profitMargin: j['profit_margin']?.toString(),
      freeToppingSlots: slots,
      hasFreeToppings: j['has_free_toppings'] as bool? ?? (slots > 0),
      hasVariants: j['has_variants'] as bool? ?? variants.isNotEmpty,
      variants: variants,
      productReady: j['product_ready'] as bool?,
      createdAt: j['created_at'],
    );
  }

  /// Produk boleh dipesan bila belum habis. `null` (tak dihitung) = boleh.
  bool get ready => productReady != false;

  /// Parse price string to num for formatting
  num get purchasePriceNum => num.tryParse(purchasePrice) ?? 0;
  num get sellingPriceNum => num.tryParse(sellingPrice) ?? 0;
  num get profitMarginNum => num.tryParse(profitMargin ?? '0') ?? 0;

  /// Harga termurah dari variant; fallback ke harga produk bila tanpa variant.
  /// Dipakai untuk tampilan kartu produk ("mulai dari …").
  num get minVariantPriceNum {
    if (variants.isEmpty) return sellingPriceNum;
    return variants
        .map((v) => v.sellingPriceNum)
        .reduce((a, b) => a < b ? a : b);
  }
}
