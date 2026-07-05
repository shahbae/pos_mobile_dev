/// Mutasi stok plastik (IN/OUT/ADJUST). Qty bisa desimal.
class PlasticStockMovement {
  final int? id;
  final int? plasticId;
  final String name;
  final String unit;
  final String? type; // "IN" | "OUT" | "ADJUST"
  final double quantity;
  final String? referenceType; // "purchase" | "sale" | "audit" | "manual" | ...
  final int? referenceId;
  final String? createdAt;

  PlasticStockMovement({
    this.id,
    this.plasticId,
    this.name = '',
    this.unit = '',
    this.type,
    this.quantity = 0,
    this.referenceType,
    this.referenceId,
    this.createdAt,
  });

  factory PlasticStockMovement.fromJson(Map<String, dynamic> j) {
    final p = j['plastic'] as Map<String, dynamic>?;
    return PlasticStockMovement(
      id: j['id'],
      plasticId: j['plastic_id'] ?? p?['id'],
      name: p?['name']?.toString() ?? j['plastic_name']?.toString() ?? 'Plastik',
      unit: p?['unit']?.toString() ?? '',
      type: j['type']?.toString(),
      quantity: double.tryParse(j['quantity']?.toString() ?? '') ?? 0,
      referenceType: j['reference_type']?.toString(),
      referenceId: j['reference_id'],
      createdAt: j['created_at']?.toString(),
    );
  }
}
