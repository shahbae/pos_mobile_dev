import 'package:pos_mobile/data/models/purchase_template_model.dart';

/// Bahan baku (material) — dipakai di stok level material & audit stok.
/// Dinamai MaterialItem agar tidak bentrok dengan Material widget Flutter.
class MaterialItem {
  final int id;
  final String name;
  final String unit;
  final String? purchaseQty;
  final String? purchasePrice;
  final String? description;
  final String? createdAt;
  final List<PurchaseTemplate> purchaseTemplates;

  MaterialItem({
    required this.id,
    required this.name,
    required this.unit,
    this.purchaseQty,
    this.purchasePrice,
    this.description,
    this.createdAt,
    this.purchaseTemplates = const [],
  });

  factory MaterialItem.fromJson(Map<String, dynamic> j) {
    return MaterialItem(
      id: j['id'],
      name: j['name'] ?? '',
      unit: j['unit'] ?? '',
      purchaseQty: j['purchase_qty']?.toString(),
      purchasePrice: j['purchase_price']?.toString(),
      description: j['description']?.toString(),
      createdAt: j['created_at'],
      purchaseTemplates: PurchaseTemplate.listFromJson(j['purchase_templates']),
    );
  }
}
