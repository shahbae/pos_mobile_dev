/// Jenis promo (mesin promo, Tahap 3).
class PromoKind {
  static const buyFree = 'buy_free';
  static const percent = 'percent';
}

/// Sasaran cakupan promo: produk, kategori, varian (pakai [id]) atau ukuran
/// seperti "XL" (pakai [value]).
class PromoTarget {
  final String type;
  final int id;
  final String value;

  const PromoTarget({required this.type, this.id = 0, this.value = ''});

  /// Menerima bentuk balasan server (`target_type`, `target_id`,
  /// `target_value`) maupun bentuk berkas kasus (`type`, `id`, `value`).
  factory PromoTarget.fromJson(Map<String, dynamic> j) => PromoTarget(
        type: (j['target_type'] ?? j['type'])?.toString() ?? '',
        id: ((j['target_id'] ?? j['id']) as num?)?.toInt() ?? 0,
        value: (j['target_value'] ?? j['value'])?.toString() ?? '',
      );
}

/// Promo dari katalog POS (`promo_rules`), lengkap dengan aturan kapan, di
/// mana, dan untuk menu apa ia berlaku. Hitungannya ada di
/// `lib/core/promo_engine.dart`.
class Promo {
  final int id;
  final String name;
  final String kind;
  final int buyQty;
  final int freeQty;
  final int percent;
  final bool isActive;

  /// Hari berlaku, konvensi BE: 0=Minggu, 1=Senin, ... 6=Sabtu
  final List<int> days;

  /// `all` = seluruh keranjang; `targets` = hanya yang cocok dengan [targets].
  final String scope;
  final List<PromoTarget> targets;
  final bool includeToppings;
  final int minSpend;
  final int maxDiscount;

  /// "HH:MM" jam WIB; kosong = sepanjang hari. Jam selesai tidak termasuk.
  final String startTime;
  final String endTime;

  /// "YYYY-MM-DD", keduanya termasuk; kosong = tanpa batas.
  final String startDate;
  final String endDate;

  /// Outlet tempat promo berlaku; kosong = semua outlet.
  final List<int> branchIds;
  final bool channelPos;
  final bool channelPickup;
  final int limitTotal;
  final int limitDaily;
  final bool stackable;

  final String? createdAt;

  Promo({
    required this.id,
    required this.name,
    this.kind = PromoKind.buyFree,
    this.buyQty = 0,
    this.freeQty = 0,
    this.percent = 0,
    this.isActive = true,
    this.days = const [],
    this.scope = 'all',
    this.targets = const [],
    this.includeToppings = true,
    this.minSpend = 0,
    this.maxDiscount = 0,
    this.startTime = '',
    this.endTime = '',
    this.startDate = '',
    this.endDate = '',
    this.branchIds = const [],
    this.channelPos = true,
    this.channelPickup = false,
    this.limitTotal = 0,
    this.limitDaily = 0,
    this.stackable = false,
    this.createdAt,
  });

  bool get isBuyFree => kind == PromoKind.buyFree;
  bool get isPercent => kind == PromoKind.percent;

  /// Menerima bentuk `GET /promos` dan katalog (`days` berisi objek,
  /// `branches`, `is_active`) maupun bentuk berkas kasus mesin promo (`days`
  /// berisi angka, `branch_ids`, `active`).
  factory Promo.fromJson(Map<String, dynamic> j) {
    final rawDays = j['days'] as List? ?? const [];
    final days = rawDays.map<int>((d) {
      if (d is Map) return (d['day_of_week'] as num).toInt();
      return (d as num).toInt(); // fallback bila BE kirim list angka langsung
    }).toList();
    final branchIds = <int>[
      for (final b in (j['branches'] as List? ?? const []))
        if (b is Map) (b['branch_id'] as num).toInt() else (b as num).toInt(),
      for (final b in (j['branch_ids'] as List? ?? const [])) (b as num).toInt(),
    ];
    String str(String key) => j[key]?.toString() ?? '';
    int whole(String key) => (j[key] as num?)?.toInt() ?? 0;
    final kind = str('kind');

    return Promo(
      id: (j['id'] as num).toInt(),
      name: j['name']?.toString() ?? '',
      kind: kind.isEmpty ? PromoKind.buyFree : kind,
      buyQty: whole('buy_qty'),
      freeQty: whole('free_qty'),
      percent: whole('percent'),
      isActive: (j['is_active'] ?? j['active']) as bool? ?? true,
      days: days,
      scope: str('scope').isEmpty ? 'all' : str('scope'),
      targets: [
        for (final t in (j['targets'] as List? ?? const []))
          PromoTarget.fromJson(Map<String, dynamic>.from(t as Map)),
      ],
      includeToppings: j['include_toppings'] as bool? ?? true,
      minSpend: whole('min_spend'),
      maxDiscount: whole('max_discount'),
      startTime: str('start_time'),
      endTime: str('end_time'),
      startDate: str('start_date'),
      endDate: str('end_date'),
      branchIds: branchIds,
      channelPos: j['channel_pos'] as bool? ?? true,
      channelPickup: j['channel_pickup'] as bool? ?? false,
      limitTotal: whole('limit_total'),
      limitDaily: whole('limit_daily'),
      stackable: j['stackable'] as bool? ?? false,
      createdAt: j['created_at']?.toString(),
    );
  }

  /// Promo lama (`promos` di katalog server sebelum Tahap 3): beli X gratis Y
  /// yang hanya berlaku bila semua item berukuran XL. Server baru memigrasinya
  /// ke bentuk yang sama persis.
  factory Promo.legacyXL(Map<String, dynamic> j) {
    final p = Promo.fromJson(j);
    return Promo(
      id: p.id,
      name: p.name,
      buyQty: p.buyQty,
      freeQty: p.freeQty,
      isActive: p.isActive,
      days: p.days,
      scope: 'targets',
      targets: const [PromoTarget(type: 'size', value: 'XL')],
      createdAt: p.createdAt,
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
