/// Mutasi stok topping (IN/OUT/ADJUST). Qty bisa desimal.
class ToppingStockMovement {
  final int? id;
  final int? toppingId;
  final String name;
  final String unit;
  final String? type; // "IN" | "OUT" | "ADJUST"
  final double quantity;
  final String? referenceType; // "purchase" | "manual" | ...
  final int? referenceId;
  final String? createdAt;

  ToppingStockMovement({
    this.id,
    this.toppingId,
    this.name = '',
    this.unit = '',
    this.type,
    this.quantity = 0,
    this.referenceType,
    this.referenceId,
    this.createdAt,
  });

  factory ToppingStockMovement.fromJson(Map<String, dynamic> j) {
    final t = j['topping'] as Map<String, dynamic>?;
    return ToppingStockMovement(
      id: j['id'],
      toppingId: j['topping_id'] ?? t?['id'],
      name: t?['name']?.toString() ?? j['topping_name']?.toString() ?? 'Topping',
      unit: t?['unit']?.toString() ?? '',
      type: j['type']?.toString(),
      quantity: double.tryParse(j['quantity']?.toString() ?? '') ?? 0,
      referenceType: j['reference_type']?.toString(),
      referenceId: j['reference_id'],
      createdAt: j['created_at']?.toString(),
    );
  }
}
