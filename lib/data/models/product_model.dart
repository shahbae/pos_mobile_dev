class Product {
  final int id;
  final int? tenantId;
  final String? sku;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final String purchasePrice;
  final String sellingPrice;
  final String? profitMargin;
  final String? createdAt;

  Product({
    required this.id,
    this.tenantId,
    this.sku,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.purchasePrice,
    required this.sellingPrice,
    this.profitMargin,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;

    return Product(
      id: j['id'],
      tenantId: j['tenant_id'],
      sku: j['sku'],
      name: j['name'],
      categoryId: cat != null ? cat['id'] : j['category_id'],
      categoryName: cat != null ? cat['name'] : j['category_name'],
      purchasePrice: j['purchase_price']?.toString() ?? '0',
      sellingPrice: j['selling_price']?.toString() ?? '0',
      profitMargin: j['profit_margin']?.toString(),
      createdAt: j['created_at'],
    );
  }

  /// Parse price string to num for formatting
  num get purchasePriceNum => num.tryParse(purchasePrice) ?? 0;
  num get sellingPriceNum => num.tryParse(sellingPrice) ?? 0;
  num get profitMarginNum => num.tryParse(profitMargin ?? '0') ?? 0;
}
