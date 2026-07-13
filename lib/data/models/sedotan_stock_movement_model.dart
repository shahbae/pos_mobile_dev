/// Mutasi stok sedotan (IN/OUT/ADJUST). Qty bisa desimal.
class SedotanStockMovement {
  final int? id;
  final int? sedotanId;
  final String name;
  final String unit;
  final String? type; // "IN" | "OUT" | "ADJUST"
  final double quantity;
  final String? referenceType; // "purchase" | "sale" | "audit" | "manual" | ...
  final int? referenceId;
  final String? createdAt;

  SedotanStockMovement({
    this.id,
    this.sedotanId,
    this.name = '',
    this.unit = '',
    this.type,
    this.quantity = 0,
    this.referenceType,
    this.referenceId,
    this.createdAt,
  });

  factory SedotanStockMovement.fromJson(Map<String, dynamic> j) {
    final s = j['sedotan'] as Map<String, dynamic>?;
    return SedotanStockMovement(
      id: j['id'],
      sedotanId: j['sedotan_id'] ?? s?['id'],
      name: s?['name']?.toString() ?? j['sedotan_name']?.toString() ?? 'Sedotan',
      unit: s?['unit']?.toString() ?? '',
      type: j['type']?.toString(),
      quantity: double.tryParse(j['quantity']?.toString() ?? '') ?? 0,
      referenceType: j['reference_type']?.toString(),
      referenceId: j['reference_id'],
      createdAt: j['created_at']?.toString(),
    );
  }
}
