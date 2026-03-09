class PurchaseModel {
  final int? id;
  final int? supplierId;
  final String? supplierName;
  final String? note;
  final String? createdAt;
  final String? totalAmount; 
  final List<PurchaseItemModel>? items;

  PurchaseModel({
    this.id,
    this.supplierId,
    this.supplierName,
    this.note,
    this.createdAt,
    this.totalAmount,
    this.items,
  });

  factory PurchaseModel.fromJson(Map<String, dynamic> j) {
    final supp = j['supplier'] as Map<String, dynamic>?;

    return PurchaseModel(
      id: j['id'] ?? j['purchase_id'],
      supplierId: j['supplier_id'],
      supplierName: supp?['name'],
      note: j['note'],
      createdAt: j['created_at'],
      totalAmount: j['total_amount']?.toString(),
      items: j['items'] != null
          ? (j['items'] as List).map((e) => PurchaseItemModel.fromJson(e)).toList()
          : null,
    );
  }
}

class PurchaseItemModel {
  final int? id;
  final int? productId;
  final String? productName;
  final int quantity;
  final String? unitCost;
  final String? subtotal;

  PurchaseItemModel({
    this.id,
    this.productId,
    this.productName,
    this.quantity = 0,
    this.unitCost,
    this.subtotal,
  });

  factory PurchaseItemModel.fromJson(Map<String, dynamic> j) {
    final prod = j['product'] as Map<String, dynamic>?;
    return PurchaseItemModel(
      id: j['id'],
      productId: j['product_id'],
      productName: prod?['name'],
      quantity: j['quantity'] ?? 0,
      unitCost: j['unit_cost']?.toString(),
      subtotal: j['subtotal']?.toString(),
    );
  }
}
