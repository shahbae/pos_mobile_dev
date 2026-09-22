import 'package:intl/intl.dart';

/// Satu entri kemasan (PurchaseTemplate) untuk konversi qty on-hand ke kemasan.
///
/// Contoh: stok 2400 gram dgn template Pack(base_qty=1000) →
/// whole=2, remainder=400, exact=2.4 → "2 Pack + 400 gram".
class StockPack {
  final int templateId;
  final String name;
  final double baseQty;
  final double whole;
  final double remainder;
  final double exact;

  StockPack({
    required this.templateId,
    this.name = '',
    this.baseQty = 0,
    this.whole = 0,
    this.remainder = 0,
    this.exact = 0,
  });

  factory StockPack.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return StockPack(
      templateId: (j['template_id'] as num?)?.toInt() ??
          int.tryParse(j['template_id']?.toString() ?? '') ??
          0,
      name: j['name']?.toString() ?? '',
      baseQty: d(j['base_qty']),
      whole: d(j['whole']),
      remainder: d(j['remainder']),
      exact: d(j['exact']),
    );
  }

  /// Hitung sendiri kemasan untuk [qty] satuan dasar, untuk layar yang
  /// mengetahui templatenya tapi tidak menerima `pack` dari BE. Aturannya
  /// meniru buildPacks di BE: minus atau template kosong → utuh 0, sisa = qty.
  factory StockPack.of({
    required double qty,
    required int templateId,
    required String name,
    required double baseQty,
  }) {
    if (baseQty <= 0 || qty < 0) {
      return StockPack(
          templateId: templateId, name: name, baseQty: baseQty, remainder: qty);
    }
    final whole = (qty / baseQty + 1e-9).floorToDouble();
    final rem = ((qty - whole * baseQty) * 10000).roundToDouble() / 10000;
    return StockPack(
      templateId: templateId,
      name: name,
      baseQty: baseQty,
      whole: whole,
      remainder: rem,
      exact: qty / baseQty,
    );
  }

  static StockPack? tryFrom(dynamic v) =>
      v is Map<String, dynamic> ? StockPack.fromJson(v) : null;

  static List<StockPack> listFrom(dynamic v) {
    if (v is! List) return const [];
    return v
        .whereType<Map<String, dynamic>>()
        .map((e) => StockPack.fromJson(e))
        .toList();
  }

  static String _fmt(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  /// Kalimat pendek yang dibaca orang gudang/outlet: "2 Jerigen + 500 ml",
  /// "2 Jerigen", atau "500 ml" bila belum sampai satu kemasan.
  String label(String unit) {
    final f = NumberFormat.decimalPattern('id_ID');
    String n(double q) => f.format(q == q.roundToDouble() ? q.toInt() : q);
    final rest = '${n(remainder)} $unit'.trim();
    if (whole <= 0) return rest;
    final packs = '${n(whole)} $name'.trim();
    return remainder == 0 ? packs : '$packs + $rest';
  }

  /// Ringkasan kemasan: `{whole} {name} × {base_qty}` + sisa bila ada.
  /// - Habis pas → "1 Pack × 3"
  /// - Ada sisa  → "2 Pack × 1 (+500 gram)"
  ///
  /// [unit] = satuan dasar item (gram/pcs/…).
  String summary(String unit) {
    final base = '${_fmt(whole)} $name × ${_fmt(baseQty)}'.trim();
    if (remainder == 0) return base;
    return '$base (+${_fmt(remainder)} $unit)'.trim();
  }
}
