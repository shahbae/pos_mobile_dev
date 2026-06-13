/// Bahan baku (material) — dipakai di stok level material & audit stok.
/// Dinamai MaterialItem agar tidak bentrok dengan Material widget Flutter.
class MaterialItem {
  final int id;
  final String name;
  final String unit;
  final String? purchasePrice;
  final String? description;
  final String? createdAt;

  MaterialItem({
    required this.id,
    required this.name,
    required this.unit,
    this.purchasePrice,
    this.description,
    this.createdAt,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> j) {
    return MaterialItem(
      id: j['id'],
      name: j['name'] ?? '',
      unit: j['unit'] ?? '',
      purchasePrice: j['purchase_price']?.toString(),
      description: j['description']?.toString(),
      createdAt: j['created_at'],
    );
  }
}
