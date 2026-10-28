/// Alasan diskon manual, dikelola owner/SPV dari web. Kasir wajib memilih
/// salah satu yang aktif saat memberi diskon.
class DiscountReason {
  final int id;
  final String name;
  final int sort;
  final bool isActive;

  const DiscountReason({required this.id, required this.name, this.sort = 0, this.isActive = true});

  factory DiscountReason.fromJson(Map<String, dynamic> j) => DiscountReason(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        sort: (j['sort'] as num?)?.toInt() ?? 0,
        isActive: j['is_active'] as bool? ?? true,
      );
}
