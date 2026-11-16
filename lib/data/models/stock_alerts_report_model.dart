import 'package:pos_mobile/data/models/stock_pack_model.dart';

/// Satu barang yang menipis di satu cabang (revisi 15 Nov, poin 6).
///
/// Batas stok kini per barang dan dalam kemasan (mis. 2 Jerigen), diatur owner
/// atau SPV. Barang tanpa batas tidak pernah muncul.
class StockAlertsRow {
  /// `material` | `topping` | `plastic` | `sedotan`.
  final String itemType;
  final int id;
  final String name;
  final String unit;
  final int branchId;
  final String branchName;

  /// Stok dalam satuan dasar (gram, ml, pcs).
  final double qtyOnHand;

  /// Satu kemasan: yang dipakai batas. `exact` = stok dalam kemasan itu.
  final StockPack? pack;
  final double thresholdPacks;
  final String thresholdPackName;
  final DateTime? updatedAt;

  const StockAlertsRow({
    required this.itemType,
    required this.id,
    required this.name,
    required this.unit,
    this.branchId = 0,
    this.branchName = '',
    required this.qtyOnHand,
    this.pack,
    this.thresholdPacks = 0,
    this.thresholdPackName = '',
    this.updatedAt,
  });

  factory StockAlertsRow.fromJson(Map<String, dynamic> json) {
    double d(dynamic raw) => double.tryParse(raw?.toString() ?? '') ?? 0;
    int i(dynamic raw) => raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? 0;
    final packs = StockPack.listFrom(json['packs']);
    return StockAlertsRow(
      itemType: (json['item_type'] ?? 'material').toString(),
      id: i(json['id']),
      name: (json['name'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      branchId: i(json['branch_id']),
      branchName: (json['branch_name'] ?? '').toString(),
      qtyOnHand: d(json['qty_on_hand']),
      pack: packs.isEmpty ? null : packs.first,
      thresholdPacks: d(json['threshold_packs']),
      thresholdPackName: (json['threshold_pack_name'] ?? '').toString(),
      // Hanya bahan yang membawa updated_at; jangan sampai yang kosong menjatuhkan layar.
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }

  bool get isNegative => qtyOnHand < 0;

  String get typeLabel => switch (itemType) {
        'topping' => 'Topping',
        'plastic' => 'Plastik',
        'sedotan' => 'Sedotan',
        _ => 'Bahan',
      };

  /// "1,4 Jerigen"; stok minus atau tanpa kemasan jatuh ke satuan dasar.
  String get stockText {
    final p = pack;
    if (p != null && !isNegative) return '${_num(p.exact)} ${p.name}'.trim();
    return '${_num(qtyOnHand)} $unit'.trim();
  }

  /// "2 Jerigen".
  String get thresholdText => '${_num(thresholdPacks)} $thresholdPackName'.trim();

  /// Stok dalam satuan dasar, pembanding di samping angka kemasan: "1.400 ml".
  String get baseText => '${_num(qtyOnHand)} $unit'.trim();
}

class StockAlertsData {
  final List<StockAlertsRow> rows;

  const StockAlertsData({required this.rows});

  factory StockAlertsData.fromJson(Map<String, dynamic> json) {
    final rawRows = (json['rows'] as List?) ?? const [];
    return StockAlertsData(
      rows: rawRows
          .whereType<Map>()
          .map((e) => StockAlertsRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

String _num(double v) {
  final r = (v * 100).round() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  return r.toString().replaceAll('.', ',');
}
