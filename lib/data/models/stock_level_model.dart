class StockLevelModel {
  final int? id;
  final int? tenantId;
  final int? productId;
  final int? materialId;
  final int? qtyOnHand;
  final String? updatedAt;

  StockLevelModel({
    this.id,
    this.tenantId,
    this.productId,
    this.materialId,
    this.qtyOnHand,
    this.updatedAt,
  });

  factory StockLevelModel.fromJson(Map<String, dynamic> j) {
    return StockLevelModel(
      id: j['id'],
      tenantId: j['tenant_id'],
      productId: j['product_id'],
      materialId: j['material_id'],
      qtyOnHand: j['qty_on_hand'],
      updatedAt: j['updated_at'],
    );
  }
}
