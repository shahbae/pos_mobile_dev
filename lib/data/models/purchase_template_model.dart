/// Template pembelian untuk material/topping (revisi BE 2026-06-29).
/// User memilih template (mis. "Pack" = 500 gram) + berapa banyak, BE menghitung
/// konversi ke base unit & total dari harga master.
class PurchaseTemplate {
  final int id;
  final String name;
  final String baseQty; // jumlah base unit per 1 template (string, mis. "500")

  const PurchaseTemplate({
    required this.id,
    required this.name,
    required this.baseQty,
  });

  num get baseQtyNum => num.tryParse(baseQty) ?? 0;

  factory PurchaseTemplate.fromJson(Map<String, dynamic> j) {
    return PurchaseTemplate(
      id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      name: j['name']?.toString() ?? '',
      baseQty: j['base_qty']?.toString() ?? '0',
    );
  }

  static List<PurchaseTemplate> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => PurchaseTemplate.fromJson(e))
        .toList();
  }
}
