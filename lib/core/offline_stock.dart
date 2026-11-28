// Stok offline (revisi owner 28 Nov 2026).
//
// Selama offline HP menghitung sendiri stok yang terpakai, dan menolak
// penjualan yang stoknya tidak cukup — sama seperti server menolaknya saat
// online. Contoh owner: gula 300 g, offline, jual yang butuh 200 g → boleh,
// sisa 100 g; jual lagi yang butuh 200 g → ditolak.
//
// Titik awalnya stok cabang dari jawaban katalog terakhir (`stock`), dikurangi
// penjualan offline yang belum tercatat di angka itu. Aturan potongnya
// (`stock_rules`) disalin dari server dan dihitung di sini persis seperti
// `Create` di be-pos: item digabung per produk+varian, resep varian (atau resep
// produk bila tanpa varian) × jumlah, topping × pemakaian per porsi, kemasan
// otomatis per varian (tumbler meniadakan wadah), lalu plastik dan sedotan
// pilihan kasir. Kemasan otomatis sudah dicari server per varian, persis seperti
// saat bayar, jadi HP tidak mencocokkan nama varian sendiri.
//
// Semua jumlah disimpan sebagai bilangan bulat per 1/10000 satuan ([stockScale])
// — angka stok di server desimal 4 angka di belakang koma — supaya 0,1 × 3
// tetap tepat 0,3 dan tidak pernah ada penolakan karena galat pembulatan.

/// 1 satuan = 10000 unit hitung.
const stockScale = 10000;

/// Jenis barang stok, sama dengan `item_type` di server.
abstract final class StockItemType {
  static const material = 'material';
  static const topping = 'topping';
  static const plastic = 'plastic';
  static const sedotan = 'sedotan';

  static const order = [material, topping, plastic, sedotan];
}

/// Kunci satu barang stok, mis. `material:3`.
String stockKey(String type, int id) => '$type:$id';

/// Baca jumlah desimal dari server (teks "150", "0.25", atau angka) menjadi
/// unit hitung. null bila tidak terbaca.
int? parseStockQty(Object? v) {
  if (v is int) return v * stockScale;
  if (v is num) return (v * stockScale).round();
  if (v is! String) return null;
  final s = v.trim();
  final m = RegExp(r'^(-?)(\d*)(?:\.(\d*))?$').firstMatch(s);
  if (m == null || (m.group(2)!.isEmpty && (m.group(3) ?? '').isEmpty)) return null;
  final negative = m.group(1) == '-';
  final whole = int.parse(m.group(2)!.isEmpty ? '0' : m.group(2)!);
  var frac = m.group(3) ?? '';
  // Lebih dari 4 angka di belakang koma tidak pernah dikirim server; kalau ada,
  // dibulatkan ke unit terdekat.
  var roundUp = false;
  if (frac.length > 4) {
    roundUp = frac.codeUnitAt(4) >= 0x35; // '5'
    frac = frac.substring(0, 4);
  }
  var units = whole * stockScale + int.parse(frac.padRight(4, '0'));
  if (roundUp) units++;
  return negative ? -units : units;
}

/// Tulis unit hitung seperti server menulis jumlah di pesannya: titik desimal,
/// tanpa nol di belakang ("100", "0.5").
String formatStockQty(int units) {
  final negative = units < 0;
  final abs = units.abs();
  final whole = abs ~/ stockScale;
  var frac = (abs % stockScale).toString().padLeft(4, '0');
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  final text = frac.isEmpty ? '$whole' : '$whole.$frac';
  return negative ? '-$text' : text;
}

class StockRecipeLine {
  final int materialId;
  final int qty;
  const StockRecipeLine(this.materialId, this.qty);
}

class StockPackagingRule {
  final String itemType;
  final int itemId;
  final int qty;

  /// Cup/sealer: ditiadakan oleh tumbler pembeli.
  final bool wadah;
  const StockPackagingRule({required this.itemType, required this.itemId, required this.qty, required this.wadah});
}

class StockItemInfo {
  final String name;
  final String unit;
  const StockItemInfo(this.name, this.unit);
}

/// Aturan potong stok dari katalog (`stock_rules`).
class StockRules {
  final Map<int, List<StockRecipeLine>> productRecipes;
  final Map<int, List<StockRecipeLine>> variantRecipes;

  /// Stok topping yang terpakai untuk satu porsi, per topping.
  final Map<int, int> toppingUsage;

  /// Kemasan otomatis per id varian, dan untuk item tanpa varian.
  final Map<int, List<StockPackagingRule>> variantPackaging;
  final List<StockPackagingRule> plainPackaging;

  /// Nama (dan satuan bahan) per [stockKey], untuk pesan penolakan.
  final Map<String, StockItemInfo> items;

  const StockRules({
    this.productRecipes = const {},
    this.variantRecipes = const {},
    this.toppingUsage = const {},
    this.variantPackaging = const {},
    this.plainPackaging = const [],
    this.items = const {},
  });

  /// Baca `stock_rules`. Melempar bila bentuknya rusak.
  factory StockRules.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String key) => [
      for (final e in (j[key] as List? ?? const []))
        if (e is Map) Map<String, dynamic>.from(e),
    ];
    int id(Object? v) => (v as num).toInt();

    final productRecipes = <int, List<StockRecipeLine>>{};
    for (final r in list('product_recipes')) {
      (productRecipes[id(r['product_id'])] ??= []).add(
        StockRecipeLine(id(r['material_id']), parseStockQty(r['qty']) ?? 0),
      );
    }
    final variantRecipes = <int, List<StockRecipeLine>>{};
    for (final r in list('variant_recipes')) {
      (variantRecipes[id(r['variant_id'])] ??= []).add(
        StockRecipeLine(id(r['material_id']), parseStockQty(r['qty']) ?? 0),
      );
    }
    final toppingUsage = <int, int>{
      for (final t in list('topping_usage')) id(t['topping_id']): parseStockQty(t['usage_qty']) ?? 0,
    };
    StockPackagingRule packagingRule(Map<String, dynamic> r) => StockPackagingRule(
      itemType: r['item_type']?.toString() ?? '',
      itemId: id(r['item_id']),
      qty: (r['qty'] as num?)?.toInt() ?? 0,
      wadah: r['wadah'] == true,
    );
    final variantPackaging = <int, List<StockPackagingRule>>{};
    for (final r in list('variant_packaging')) {
      (variantPackaging[id(r['variant_id'])] ??= []).add(packagingRule(r));
    }
    final items = <String, StockItemInfo>{
      for (final it in list('items'))
        stockKey(it['item_type']?.toString() ?? '', id(it['item_id'])): StockItemInfo(
          it['name']?.toString() ?? '',
          it['unit']?.toString() ?? '',
        ),
    };
    return StockRules(
      productRecipes: productRecipes,
      variantRecipes: variantRecipes,
      toppingUsage: toppingUsage,
      variantPackaging: variantPackaging,
      plainPackaging: list('plain_packaging').map(packagingRule).toList(),
      items: items,
    );
  }

  /// Satu porsi produk/varian bisa dibuat dari [available] — aturan "siap"
  /// yang sama dengan server: setiap bahan resep tersedia ≥ takaran satu porsi.
  bool recipeReady({required int productId, int? variantId, required Map<String, int> available}) {
    final recipe = variantId != null ? variantRecipes[variantId] : productRecipes[productId];
    for (final r in recipe ?? const <StockRecipeLine>[]) {
      if ((available[stockKey(StockItemType.material, r.materialId)] ?? 0) < r.qty) return false;
    }
    return true;
  }
}

/// Stok cabang dari jawaban katalog (`stock`), beserta kapan HP menerimanya.
class StockSnapshot {
  /// Unit hitung per [stockKey]. Barang yang tidak ada = 0.
  final Map<String, int> levels;

  /// Jam HP saat jawaban diterima. Penjualan offline yang terkirim SESUDAH ini
  /// belum tercermin di [levels].
  final DateTime receivedAt;

  const StockSnapshot({required this.levels, required this.receivedAt});

  /// Baca `stock` dari server. null bila server tidak mengirimnya (server lama).
  static StockSnapshot? fromServer(Object? raw, {required DateTime receivedAt}) {
    if (raw is! List) return null;
    final levels = <String, int>{};
    for (final e in raw) {
      if (e is! Map || e['item_id'] is! num) continue;
      final qty = parseStockQty(e['qty']);
      if (qty == null) continue;
      levels[stockKey(e['item_type']?.toString() ?? '', (e['item_id'] as num).toInt())] = qty;
    }
    return StockSnapshot(levels: levels, receivedAt: receivedAt);
  }

  Map<String, dynamic> toJson() => {'received_at': receivedAt.millisecondsSinceEpoch, 'levels': levels};

  factory StockSnapshot.fromJson(Map<String, dynamic> j) => StockSnapshot(
    levels: {for (final e in Map<String, dynamic>.from(j['levels'] as Map).entries) e.key: (e.value as num).toInt()},
    receivedAt: DateTime.fromMillisecondsSinceEpoch((j['received_at'] as num).toInt()),
  );
}

/// Kebutuhan stok satu penjualan, dalam unit hitung per [stockKey].
///
/// [request] berbentuk isi permintaan bayar ke server (`items`, `plastics`,
/// `sedotans`) — persis yang dibaca `Create`, jadi penjualan online dan offline
/// dihitung dari bahan yang sama.
Map<String, int> stockNeeds(StockRules rules, Map<String, dynamic> request) {
  final needs = <String, int>{};
  void add(String key, int units) {
    if (units <= 0) return;
    needs[key] = (needs[key] ?? 0) + units;
  }

  int intOf(Object? v) => v is num ? v.toInt() : 0;
  List<Map<String, dynamic>> list(Object? raw) => [
    for (final e in (raw is List ? raw : const []))
      if (e is Map) Map<String, dynamic>.from(e),
  ];

  // Gabung per produk + varian (0 = tanpa varian), seperti server.
  final qty = <(int, int), int>{};
  final tumbler = <(int, int), int>{};
  final toppingServings = <int, int>{};
  for (final it in list(request['items'])) {
    final key = (intOf(it['product_id']), intOf(it['variant_id']));
    final lineQty = intOf(it['qty']);
    qty[key] = (qty[key] ?? 0) + lineQty;
    tumbler[key] = (tumbler[key] ?? 0) + intOf(it['tumbler_qty']);
    // Jumlah topping per gelas, dikali jumlah gelas di baris itu.
    for (final t in [...list(it['free_toppings']), ...list(it['extra_toppings'])]) {
      final tid = intOf(t['topping_id']);
      toppingServings[tid] = (toppingServings[tid] ?? 0) + intOf(t['qty']) * lineQty;
    }
  }

  for (final e in qty.entries) {
    final (productId, variantId) = e.key;
    final sold = e.value;
    if (sold <= 0) continue;

    // Bahan: resep varian, atau resep produk bila tanpa varian.
    final recipe = variantId != 0 ? rules.variantRecipes[variantId] : rules.productRecipes[productId];
    for (final r in recipe ?? const <StockRecipeLine>[]) {
      add(stockKey(StockItemType.material, r.materialId), r.qty * sold);
    }

    // Kemasan otomatis. Varian yang tidak dikenal katalog tidak ditebak.
    final matched = variantId == 0 ? rules.plainPackaging : rules.variantPackaging[variantId];
    if (matched == null) continue;
    final inTumbler = (tumbler[e.key] ?? 0).clamp(0, sold);
    for (final r in matched) {
      if (r.qty <= 0 || r.itemId == 0) continue;
      final units = (r.itemType == StockItemType.plastic && r.wadah) ? sold - inTumbler : sold;
      if (units <= 0) continue;
      if (r.itemType == StockItemType.plastic || r.itemType == StockItemType.sedotan) {
        add(stockKey(r.itemType, r.itemId), r.qty * units * stockScale);
      }
    }
  }

  // Topping: jumlah porsi × pemakaian per porsi.
  for (final e in toppingServings.entries) {
    add(stockKey(StockItemType.topping, e.key), e.value * (rules.toppingUsage[e.key] ?? 0));
  }

  // Plastik dan sedotan pilihan kasir, di atas yang otomatis.
  for (final p in list(request['plastics'])) {
    add(stockKey(StockItemType.plastic, intOf(p['plastic_id'])), intOf(p['qty']) * stockScale);
  }
  for (final s in list(request['sedotans'])) {
    add(stockKey(StockItemType.sedotan, intOf(s['sedotan_id'])), intOf(s['qty']) * stockScale);
  }
  return needs;
}

/// Stok yang masih tersedia: [snapshot] dikurangi setiap kebutuhan di
/// [consumed]. Boleh negatif (penjualan yang sudah lewat tetap dihitung).
Map<String, int> availableStock(StockSnapshot snapshot, Iterable<Map<String, int>> consumed) {
  final out = Map<String, int>.from(snapshot.levels);
  for (final needs in consumed) {
    for (final e in needs.entries) {
      out[e.key] = (out[e.key] ?? 0) - e.value;
    }
  }
  return out;
}

/// Satu barang yang tidak cukup untuk sebuah penjualan.
class StockShortage {
  final String itemType;
  final int itemId;
  final String name;
  final String unit;
  final int available;
  final int needed;

  /// Server belum pernah mencatat stok barang ini di cabang.
  final bool neverStocked;

  const StockShortage({
    required this.itemType,
    required this.itemId,
    required this.name,
    required this.unit,
    required this.available,
    required this.needed,
    required this.neverStocked,
  });

  /// Kalimat yang sama dengan penolakan server saat online.
  String get message {
    final avail = formatStockQty(available < 0 ? 0 : available);
    final need = formatStockQty(needed);
    switch (itemType) {
      case StockItemType.material:
        if (neverStocked) return 'Stok $name belum pernah diisi di cabang ini';
        final u = unit.isEmpty ? '' : ' $unit';
        return 'Stok $name tidak cukup: tersedia $avail$u, dibutuhkan $need$u';
      case StockItemType.plastic:
        return 'Stok plastik $name tidak cukup: tersedia $avail, dibutuhkan $need';
      default:
        return 'Stok $itemType $name tidak cukup: tersedia $avail, dibutuhkan $need';
    }
  }
}

/// Barang yang kebutuhannya melebihi stok tersedia, urut bahan → topping →
/// plastik → sedotan, lalu id. Kosong = penjualan boleh.
List<StockShortage> stockShortages({
  required StockRules rules,
  required Map<String, int> needs,
  required Map<String, int> available,
  required StockSnapshot snapshot,
}) {
  final out = <StockShortage>[];
  for (final e in needs.entries) {
    final have = available[e.key] ?? 0;
    if (e.value <= have) continue;
    final sep = e.key.indexOf(':');
    final type = e.key.substring(0, sep);
    final id = int.tryParse(e.key.substring(sep + 1)) ?? 0;
    final info = rules.items[e.key];
    out.add(
      StockShortage(
        itemType: type,
        itemId: id,
        name: (info == null || info.name.isEmpty) ? '${_humanKind(type)} #$id' : info.name,
        unit: info?.unit ?? '',
        available: have,
        needed: e.value,
        neverStocked: !snapshot.levels.containsKey(e.key),
      ),
    );
  }
  out.sort((a, b) {
    final t = StockItemType.order.indexOf(a.itemType).compareTo(StockItemType.order.indexOf(b.itemType));
    return t != 0 ? t : a.itemId.compareTo(b.itemId);
  });
  return out;
}

String _humanKind(String type) => switch (type) {
  StockItemType.material => 'bahan',
  StockItemType.plastic => 'plastik',
  _ => type,
};
