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
  final String? itemName;
  final String? materialName;
  final int? toppingId;
  final String? toppingName;
  final double systemQty;
  final double physicalQty;

  /// Jumlah yang dikembalikan (keluar cabang secara sah, bukan terjual/hilang).
  /// diff = physical − (system − returned), dihitung BE. Default 0.
  final double returnedQty;

  /// Info read-only: jumlah masuk (movement IN) item ini di cabang hari ini.
  /// Snapshot saat draft dibuat/di-update. Hanya konteks buat auditor.
  final double incomingToday;

  final double diff;

  /// Nilai satuan item saat audit dibuat (purchase_price material / unit_cost
  /// pembelian terakhir topping). 0 berarti harga belum pernah diinput.
  final double unitValue;

  StockAuditItem({
    this.id,
    this.materialId,
    this.itemName,
    this.materialName,
    this.toppingId,
    this.toppingName,
    this.systemQty = 0,
    this.physicalQty = 0,
    this.returnedQty = 0,
    this.incomingToday = 0,
    this.diff = 0,
    this.unitValue = 0,
  });

  /// Estimasi nilai kerugian stok: |diff| × unitValue, hanya bila stok kurang
  /// (diff < 0). 0 bila tidak ada kekurangan atau harga belum tersedia.
  double get lossValue => diff < 0 ? diff.abs() * unitValue : 0;

  /// Sumber utama nama = `item_name` (BE versi sekarang). `material_name`/
  /// `topping_name` disimpan sebagai fallback, praktis jarang terisi.
  String get displayName {
    if (itemName != null && itemName!.isNotEmpty) return itemName!;
    if (materialName != null && materialName!.isNotEmpty) return materialName!;
    if (toppingName != null && toppingName!.isNotEmpty) return toppingName!;
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
      itemName: j['item_name']?.toString(),
      materialName: j['material_name']?.toString(),
      toppingId: j['topping_id'],
      toppingName: j['topping_name']?.toString(),
      systemQty: _toDouble(j['system_qty']),
      physicalQty: _toDouble(j['physical_qty']),
      returnedQty: _toDouble(j['returned_qty']),
      incomingToday: _toDouble(j['incoming_today']),
      diff: _toDouble(j['diff']),
      unitValue: _toDouble(j['unit_value']),
    );
  }
}

/// Aman untuk num, String desimal ("500.5"), atau null.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
