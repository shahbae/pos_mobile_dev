/// Aman untuk int, num, String ("100"/"100.0"), atau null.
int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return double.tryParse(v.toString())?.toInt();
}

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
      id: _toIntOrNull(j['id'] ?? j['purchase_id']),
      supplierId: _toIntOrNull(j['supplier_id']),
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
  final int? materialId;
  final String? materialName;
  final int? toppingId;
  final String? toppingName;
  final int quantity;
  final String? unitCost;
  final String? subtotal;

  PurchaseItemModel({
    this.id,
    this.materialId,
    this.materialName,
    this.toppingId,
    this.toppingName,
    this.quantity = 0,
    this.unitCost,
    this.subtotal,
  });

  /// Nama item (material atau topping) untuk ditampilkan.
  String get displayName {
    if (materialName != null) return materialName!;
    if (toppingName != null) return toppingName!;
    if (materialId != null) return 'Material #$materialId';
    if (toppingId != null) return 'Topping #$toppingId';
    return 'Item';
  }

  /// Label jenis item.
  String? get typeLabel {
    if (materialId != null) return 'Material';
    if (toppingId != null) return 'Topping';
    return null;
  }

  factory PurchaseItemModel.fromJson(Map<String, dynamic> j) {
    final mat = j['material'] as Map<String, dynamic>?;
    final top = j['topping'] as Map<String, dynamic>?;
    return PurchaseItemModel(
      id: _toIntOrNull(j['id']),
      materialId: _toIntOrNull(j['material_id']),
      materialName: mat?['name'] ?? j['material_name'],
      toppingId: _toIntOrNull(j['topping_id']),
      toppingName: top?['name'] ?? j['topping_name'],
      quantity: _toIntOrNull(j['quantity']) ?? 0,
      unitCost: j['unit_cost']?.toString(),
      subtotal: j['subtotal']?.toString(),
    );
  }
}
