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
  final String? materialUnit;
  final int? toppingId;
  final String? toppingName;
  final String? toppingUnit;
  final int? templateId;
  final String? templateName; // mis. "Lusin"
  final String? templateBaseQty; // base unit per template
  final int? packQty; // berapa template dibeli
  final String? quantityStr; // hasil konversi ke base unit (mis. "2400.0000")
  final int quantity; // versi int dari quantityStr (kompat lama)
  final String? unitCost;
  final String? subtotal;

  PurchaseItemModel({
    this.id,
    this.materialId,
    this.materialName,
    this.materialUnit,
    this.toppingId,
    this.toppingName,
    this.toppingUnit,
    this.templateId,
    this.templateName,
    this.templateBaseQty,
    this.packQty,
    this.quantityStr,
    this.quantity = 0,
    this.unitCost,
    this.subtotal,
  });

  /// Satuan base unit item (gram/ml/pcs).
  String? get unit => materialUnit ?? toppingUnit;

  /// Kuantitas base unit terbaca (string asli bila ada, fallback int).
  String get quantityDisplay {
    final q = quantityStr;
    if (q == null) return quantity.toString();
    final n = num.tryParse(q);
    if (n == null) return q;
    // Buang desimal .0 yang tidak perlu.
    return n == n.truncate() ? n.truncate().toString() : n.toString();
  }

  /// Ringkasan untuk tampilan: "2 Lusin (= 2400 gram)".
  String? get packSummary {
    if (templateName == null || packQty == null) return null;
    final u = unit;
    final qty = quantityDisplay;
    return '$packQty $templateName (= $qty${u != null && u.isNotEmpty ? ' $u' : ''})';
  }

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
    final tpl = j['template'] as Map<String, dynamic>?;
    return PurchaseItemModel(
      id: _toIntOrNull(j['id']),
      materialId: _toIntOrNull(j['material_id']),
      materialName: mat?['name'] ?? j['material_name'],
      materialUnit: mat?['unit']?.toString(),
      toppingId: _toIntOrNull(j['topping_id']),
      toppingName: top?['name'] ?? j['topping_name'],
      toppingUnit: top?['unit']?.toString(),
      templateId: _toIntOrNull(j['template_id'] ?? tpl?['id']),
      templateName: tpl?['name']?.toString(),
      templateBaseQty: tpl?['base_qty']?.toString(),
      packQty: _toIntOrNull(j['pack_qty']),
      quantityStr: j['quantity']?.toString(),
      quantity: _toIntOrNull(j['quantity']) ?? 0,
      unitCost: j['unit_cost']?.toString(),
      subtotal: j['subtotal']?.toString(),
    );
  }
}
