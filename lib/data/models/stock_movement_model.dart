class StockMovementModel {
  final int? id;
  final int? materialId;
  final String? type; // "IN" | "OUT" | "ADJUST"
  final int? quantity;
  final String? referenceType; // "purchase" | "sales" | "manual" | "adjustment"
  final int? referenceId;
  final String? createdAt;

  StockMovementModel({
    this.id,
    this.materialId,
    this.type,
    this.quantity,
    this.referenceType,
    this.referenceId,
    this.createdAt,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> j) {
    return StockMovementModel(
      id: j['id'],
      materialId: j['material_id'],
      type: j['type'],
      quantity: j['quantity'],
      referenceType: j['reference_type'],
      referenceId: j['reference_id'],
      createdAt: j['created_at'],
    );
  }
}
