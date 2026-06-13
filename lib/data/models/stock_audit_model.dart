class StockAudit {
  final int id;
  final int? createdBy;
  final String status; // draft | approved | ...
  final String? notes;
  final int? approvedBy;
  final String? approvedAt;
  final String? createdAt;
  final List<StockAuditItem> items;

  StockAudit({
    required this.id,
    this.createdBy,
    required this.status,
    this.notes,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.items = const [],
  });

  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isApproved => status.toLowerCase() == 'approved';

  factory StockAudit.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'] as List? ?? const [];
    return StockAudit(
      id: j['id'],
      createdBy: j['created_by'],
      status: j['status']?.toString() ?? 'draft',
      notes: j['notes']?.toString(),
      approvedBy: j['approved_by'],
      approvedAt: j['approved_at']?.toString(),
      createdAt: j['created_at']?.toString(),
      items: rawItems.map((e) => StockAuditItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class StockAuditItem {
  final int? id;
  final int? materialId;
  final String? materialName;
  final int? toppingId;
  final String? toppingName;
  final double systemQty;
  final double physicalQty;
  final double diff;

  StockAuditItem({
    this.id,
    this.materialId,
    this.materialName,
    this.toppingId,
    this.toppingName,
    this.systemQty = 0,
    this.physicalQty = 0,
    this.diff = 0,
  });

  String get displayName {
    if (materialName != null) return materialName!;
    if (toppingName != null) return toppingName!;
    if (materialId != null) return 'Material #$materialId';
    if (toppingId != null) return 'Topping #$toppingId';
    return 'Item';
  }

  String? get typeLabel {
    if (materialId != null) return 'Material';
    if (toppingId != null) return 'Topping';
    return null;
  }

  factory StockAuditItem.fromJson(Map<String, dynamic> j) {
    return StockAuditItem(
      id: j['id'],
      materialId: j['material_id'],
      materialName: j['material_name']?.toString(),
      toppingId: j['topping_id'],
      toppingName: j['topping_name']?.toString(),
      systemQty: _toDouble(j['system_qty']),
      physicalQty: _toDouble(j['physical_qty']),
      diff: _toDouble(j['diff']),
    );
  }
}

/// Aman untuk num, String desimal ("500.5"), atau null.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
