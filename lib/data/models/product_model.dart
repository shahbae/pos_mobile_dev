class Product {
  final String id;
  final String? sku;
  final String name;
  final int stock;
  final int purchasePrice;
  final int sellingPrice;
  final int profitMargin;

  Product({
    required this.id,
    this.sku,
    required this.name,
    required this.stock,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.profitMargin,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    return Product(
      id: j['id'],
      sku: j['sku'],
      name: j['name'],
      stock: j['stock'],
      purchasePrice: j['purchase_price'],
      sellingPrice: j['selling_price'],
      profitMargin: j['profit_margin'],
    );
  }
}
