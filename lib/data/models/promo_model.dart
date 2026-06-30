class Promo {
  final int id;
  final String name;
  final int buyQty;
  final int freeQty;
  final bool isActive;

  /// Hari berlaku, konvensi BE: 0=Minggu, 1=Senin, ... 6=Sabtu
  final List<int> days;

  final String? createdAt;

  Promo({
    required this.id,
    required this.name,
    required this.buyQty,
    required this.freeQty,
    this.isActive = true,
    this.days = const [],
    this.createdAt,
  });

  factory Promo.fromJson(Map<String, dynamic> j) {
    final rawDays = j['days'] as List? ?? const [];
    final days = rawDays.map<int>((d) {
      if (d is Map<String, dynamic>) return (d['day_of_week'] as num).toInt();
      return (d as num).toInt(); // fallback bila BE kirim list angka langsung
    }).toList();

    return Promo(
      id: j['id'],
      name: j['name'] ?? '',
      buyQty: (j['buy_qty'] as num?)?.toInt() ?? 0,
      freeQty: (j['free_qty'] as num?)?.toInt() ?? 0,
      isActive: j['is_active'] as bool? ?? true,
      days: days,
      createdAt: j['created_at'],
    );
  }

  /// Konversi DateTime.weekday (1=Senin..7=Minggu) ke konvensi BE (0=Minggu..6=Sabtu)
  bool appliesToday() {
    final beDow = DateTime.now().weekday % 7; // Minggu(7)→0, Senin(1)→1, ...
    return days.contains(beDow);
  }

  /// Kuota item gratis maksimum berdasarkan jumlah item yang DIBAYAR.
  /// Formula BE: (qty_dibayar ÷ buy_qty) × free_qty, di mana item gratis adalah
  /// TAMBAHAN (bonus) di atas item yang dibayar — bukan mengurangi item dibayar.
  /// Mis. Beli 2 Gratis 1: 2 dibayar → 1 gratis, 4 dibayar → 2 gratis.
  int maxFreeQty(int paidQty) {
    if (buyQty <= 0 || freeQty <= 0) return 0;
    return (paidQty ~/ buyQty) * freeQty;
  }
}
