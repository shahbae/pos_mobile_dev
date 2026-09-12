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
  final int? plasticId;
  final String? plasticName;
  final int? sedotanId;
  final String? sedotanName;
  final double systemQty;
  final double physicalQty;

  /// Jumlah yang dikembalikan ke gudang pusat (keluar cabang secara sah, bukan
  /// terjual/hilang). Saat opname di-acc, jumlah ini keluar dari stok cabang dan
  /// masuk ke stok gudang pada transaksi yang sama.
  /// diff = physical − (system − returned), dihitung BE. Default 0.
  final double returnedQty;

  /// Info read-only: jumlah masuk (movement IN) item ini di cabang hari ini.
  /// Snapshot saat draft dibuat/di-update. Hanya konteks buat auditor.
  final double incomingToday;

  final double diff;

  /// Nilai satuan item saat audit dibuat (purchase_price material / unit_cost
  /// pembelian terakhir topping). 0 berarti harga belum pernah diinput.
  final double unitValue;

  /// Perubahan stok yang benar-benar diterapkan saat approve (negatif = keluar).
  /// Bisa lebih kecil dari [diff] kalau stok mentok di 0 (BE 2026-08-08 §4).
  final double appliedDelta;

  /// Bagian dari koreksi yang TIDAK bisa diterapkan karena stok mentok di 0.
  /// > 0 berarti hitung fisik & catatan penjualan bertentangan — wajib
  /// ditampilkan supaya cabang diperiksa, bukan dikoreksi diam-diam.
  final double shortfallQty;

  StockAuditItem({
    this.id,
    this.materialId,
    this.itemName,
    this.materialName,
    this.toppingId,
    this.toppingName,
    this.plasticId,
    this.plasticName,
    this.sedotanId,
    this.sedotanName,
    this.systemQty = 0,
    this.physicalQty = 0,
    this.returnedQty = 0,
    this.incomingToday = 0,
    this.diff = 0,
    this.unitValue = 0,
    this.appliedDelta = 0,
    this.shortfallQty = 0,
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
    if (plasticName != null && plasticName!.isNotEmpty) return plasticName!;
    if (sedotanName != null && sedotanName!.isNotEmpty) return sedotanName!;
    if (materialId != null) return 'Material #$materialId';
    if (toppingId != null) return 'Topping #$toppingId';
    if (plasticId != null) return 'Plastik #$plasticId';
    if (sedotanId != null) return 'Sedotan #$sedotanId';
    return 'Item';
  }

  String? get typeLabel {
    if (materialId != null) return 'Material';
    if (toppingId != null) return 'Topping';
    if (plasticId != null) return 'Plastik';
    if (sedotanId != null) return 'Sedotan';
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
      plasticId: j['plastic_id'],
      plasticName: j['plastic_name']?.toString(),
      sedotanId: j['sedotan_id'],
      sedotanName: j['sedotan_name']?.toString(),
      systemQty: _toDouble(j['system_qty']),
      physicalQty: _toDouble(j['physical_qty']),
      returnedQty: _toDouble(j['returned_qty']),
      incomingToday: _toDouble(j['incoming_today']),
      diff: _toDouble(j['diff']),
      unitValue: _toDouble(j['unit_value']),
      appliedDelta: _toDouble(j['applied_delta']),
      shortfallQty: _toDouble(j['shortfall_qty']),
    );
  }
}

/// Item yang boleh diaudit di cabang aktif (GET /stock-audits/auditable-items).
///
/// Daftarnya ditentukan owner lewat `is_auditable` di master data dan bisa
/// berubah kapan saja — FE TIDAK BOLEH menebak/hardcode item mana yang masuk
/// opname (BE 2026-08-08 §1). Response ini sudah lengkap untuk membangun form,
/// jadi tidak perlu memanggil /materials, /toppings, /plastics, /sedotans.
class AuditableItem {
  /// `material` | `topping` | `plastic` | `sedotan`.
  final String type;
  final int? materialId;
  final int? toppingId;
  final int? plasticId;
  final int? sedotanId;
  final String name;
  final String unit;

  /// Stok menurut sistem di cabang tsb.
  final double systemQty;

  /// Jumlah masuk (movement IN) hari ini — konteks buat yang menghitung.
  final double incomingToday;

  AuditableItem({
    required this.type,
    this.materialId,
    this.toppingId,
    this.plasticId,
    this.sedotanId,
    required this.name,
    this.unit = '',
    this.systemQty = 0,
    this.incomingToday = 0,
  });

  /// Id yang terisi mengikuti [type]; null kalau BE mengirim tipe yang belum
  /// dikenal app ini (item begitu di-skip, bukan bikin form gagal).
  int? get id => materialId ?? toppingId ?? plasticId ?? sedotanId;

  /// Kunci unik lintas tipe untuk state form (mis. "material:7").
  String get key => '$type:$id';

  /// Field id sesuai [type] — nama fieldnya sama persis dengan yang diminta
  /// POST/PUT /stock-audits, jadi bisa diteruskan apa adanya.
  Map<String, dynamic> get idPayload => {
        if (materialId != null) 'material_id': materialId,
        if (toppingId != null) 'topping_id': toppingId,
        if (plasticId != null) 'plastic_id': plasticId,
        if (sedotanId != null) 'sedotan_id': sedotanId,
      };

  String get typeLabel {
    switch (type) {
      case 'material':
        return 'Material';
      case 'topping':
        return 'Topping';
      case 'plastic':
        return 'Plastik';
      case 'sedotan':
        return 'Sedotan';
      default:
        return type;
    }
  }

  factory AuditableItem.fromJson(Map<String, dynamic> j) {
    return AuditableItem(
      type: j['type']?.toString() ?? '',
      materialId: j['material_id'],
      toppingId: j['topping_id'],
      plasticId: j['plastic_id'],
      sedotanId: j['sedotan_id'],
      name: j['name']?.toString() ?? '',
      unit: j['unit']?.toString() ?? '',
      systemQty: _toDouble(j['system_qty']),
      incomingToday: _toDouble(j['incoming_today']),
    );
  }
}

/// Aman untuk num, String desimal ("500.5"), atau null.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
