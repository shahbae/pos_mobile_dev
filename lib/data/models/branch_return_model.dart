// Retur Stok harian (revisi owner 26 Nov 2026): barang dikirim balik ke gudang
// tanpa hitung fisik. Teh dan gula (barang audit harian/mingguan) tidak ada di
// sini — returnya lewat opname harian/mingguan.

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// Barang yang boleh diretur, dengan stok sistem outlet.
class BranchReturnItem {
  /// `material` | `topping` | `plastic` | `sedotan`.
  final String itemType;
  final int itemId;
  final String name;
  final String unit;
  final double systemQty;

  const BranchReturnItem({
    required this.itemType,
    required this.itemId,
    required this.name,
    this.unit = '',
    this.systemQty = 0,
  });

  String get key => '$itemType-$itemId';

  factory BranchReturnItem.fromJson(Map<String, dynamic> j) => BranchReturnItem(
        itemType: '${j['item_type'] ?? ''}',
        itemId: _int(j['item_id']),
        name: '${j['name'] ?? ''}',
        unit: '${j['unit'] ?? ''}',
        systemQty: _num(j['system_qty']),
      );
}

/// Satu barang dalam dokumen retur harian.
class BranchReturnLine {
  final String name;
  final String unit;
  final double returnedQty;
  final double receivedQty;
  final double discardedQty;
  final double missingQty;

  const BranchReturnLine({
    required this.name,
    this.unit = '',
    this.returnedQty = 0,
    this.receivedQty = 0,
    this.discardedQty = 0,
    this.missingQty = 0,
  });

  factory BranchReturnLine.fromJson(Map<String, dynamic> j) => BranchReturnLine(
        name: '${j['item_name'] ?? ''}',
        unit: '${j['unit'] ?? ''}',
        returnedQty: _num(j['returned_qty']),
        receivedQty: _num(j['return_received_qty']),
        discardedQty: _num(j['return_discarded_qty']),
        missingQty: _num(j['return_missing_qty']),
      );
}

/// Retur harian satu outlet satu hari (digabung selama gudang belum memilah).
class BranchReturnDoc {
  final int id;
  final DateTime? createdAt;

  /// `pending` (dalam perjalanan ke gudang) | `received` (sudah dipilah).
  final String status;
  final String notes;
  final List<BranchReturnLine> lines;

  const BranchReturnDoc({required this.id, this.createdAt, this.status = 'pending', this.notes = '', this.lines = const []});

  bool get received => status == 'received';

  factory BranchReturnDoc.fromJson(Map<String, dynamic> j) => BranchReturnDoc(
        id: _int(j['id']),
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
        status: '${j['return_status'] ?? 'pending'}',
        notes: '${j['notes'] ?? ''}',
        lines: [
          if (j['items'] is List)
            for (final e in j['items'] as List)
              if (e is Map) BranchReturnLine.fromJson(Map<String, dynamic>.from(e)),
        ],
      );
}
