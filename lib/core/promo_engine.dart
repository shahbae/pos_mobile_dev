import 'package:pos_mobile/data/models/promo_model.dart';

// Mesin promo (Tahap 3, F8) dan diskon manual (F9): hitungan murni tanpa
// jaringan, salinan be-pos internal/services/promo_engine.go. Keduanya diuji
// dengan kumpulan kasus yang sama (test/fixtures/promo_cases.json, salinan
// berkas di be-pos). Aturan yang berubah di sana wajib berubah di sini, dan
// kasus barunya ditambahkan di berkas be-pos lalu disalin — bukan di tes ini
// saja.
//
// Server tetap yang memutuskan: penjualan online yang totalnya berbeda dengan
// hitungan server ditolak (409), penjualan offline mencatat selisihnya.

/// Satu baris keranjang (produk + varian) yang sudah dihargai. Baris dengan
/// produk dan varian yang sama digabung, persis seperti server menggabungnya.
class PricingLine {
  final int productId;
  final int variantId;
  final int categoryId;
  final String productName;
  final String variantName;
  final int qty;
  final int unitPrice;

  /// Seluruh topping berbayar di baris ini (semua gelas).
  final int toppingAmount;

  /// Berapa gelas di baris ini yang digratiskan beli X gratis Y. Gelas itu
  /// tidak ikut dasar potongan persen; toppingnya tetap ikut.
  final int freeQty;

  const PricingLine({
    required this.productId,
    this.variantId = 0,
    this.categoryId = 0,
    required this.productName,
    this.variantName = '',
    required this.qty,
    required this.unitPrice,
    this.toppingAmount = 0,
    this.freeQty = 0,
  });

  factory PricingLine.fromJson(Map<String, dynamic> j) {
    int whole(String key) => (j[key] as num?)?.toInt() ?? 0;
    return PricingLine(
      productId: whole('product_id'),
      variantId: whole('variant_id'),
      categoryId: whole('category_id'),
      productName: j['product_name']?.toString() ?? '',
      variantName: j['variant_name']?.toString() ?? '',
      qty: whole('qty'),
      unitPrice: whole('unit_price'),
      toppingAmount: whole('topping_amount'),
      freeQty: whole('free_qty'),
    );
  }

  String get label => variantName.isNotEmpty ? '$productName $variantName' : productName;
}

/// Berapa transaksi yang sudah memakai sebuah promo.
class PromoUsage {
  final int total;
  final int today;

  const PromoUsage({this.total = 0, this.today = 0});

  static const none = PromoUsage();
}

/// Diskon manual yang diminta kasir.
class ManualDiscountInput {
  /// `percent` atau `amount`.
  final String kind;

  /// Persen bulat atau rupiah.
  final int value;
  final int limitPct;

  /// Alasan dipilih dan masih aktif.
  final bool hasReason;

  const ManualDiscountInput({
    required this.kind,
    required this.value,
    required this.limitPct,
    required this.hasReason,
  });
}

/// Promo yang memotong transaksi.
class AppliedPromo {
  final int id;
  final String name;
  final int discount;

  const AppliedPromo({required this.id, required this.name, required this.discount});
}

/// Aturan yang dilanggar. Online: penjualan ditolak. Offline: dicatat sebagai
/// selisih.
class PricingViolation {
  static const discountWithPromo = 'discount_with_promo';
  static const discountLimit = 'discount_limit';
  static const discountReason = 'discount_reason';
  static const discountInvalid = 'discount_invalid';

  final String code;
  final String message;

  const PricingViolation(this.code, this.message);
}

/// Hasil satu hitungan.
class PricingResult {
  final int subtotal;

  /// Promo persen yang terpasang; null bila tidak ada.
  final AppliedPromo? percent;

  /// Promo persen yang cocok tapi dilepas karena beli X gratis Y yang dipilih
  /// kasir tidak boleh digabung. Kasir diberi tahu namanya.
  final AppliedPromo? droppedPercent;

  /// Potongan beli X gratis Y yang sudah dihitung pemanggil.
  final int freeDiscount;
  final int manualDiscount;
  final int manualPercent;
  final int total;
  final List<PricingViolation> violations;

  const PricingResult({
    required this.subtotal,
    this.percent,
    this.droppedPercent,
    this.freeDiscount = 0,
    this.manualDiscount = 0,
    this.manualPercent = 0,
    required this.total,
    this.violations = const [],
  });

  /// Potongan semua promo (beli X gratis Y + persen).
  int get promoDiscount => freeDiscount + (percent?.discount ?? 0);
}

/// Harga semua gelas ditambah topping berbayar, sebelum potongan.
int pricingSubtotal(List<PricingLine> lines) =>
    lines.fold(0, (sum, l) => sum + l.unitPrice * l.qty + l.toppingAmount);

const _weekdays = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

/// Jam dinding WIB untuk sebuah saat: tanggal, jam, dan hari dibaca dari
/// hasilnya, berapa pun zona waktu HP.
DateTime wibWallClock(DateTime instant) => instant.toUtc().add(const Duration(hours: 7));

/// Token ukuran sebagai kata utuh, tanpa membedakan huruf besar-kecil.
RegExp _sizeToken(String token) =>
    RegExp(r'\b' + RegExp.escape(token.trim()) + r'\b', caseSensitive: false);

/// Apakah satu baris keranjang masuk cakupan promo.
bool lineInScope(Promo p, PricingLine l) {
  if (p.scope != 'targets') return true;
  for (final t in p.targets) {
    switch (t.type) {
      case 'product':
        if (t.id != 0 && t.id == l.productId) return true;
      case 'category':
        if (t.id != 0 && t.id == l.categoryId) return true;
      case 'variant':
        if (t.id != 0 && t.id == l.variantId) return true;
      case 'size':
        if (t.value.isEmpty) continue;
        final re = _sizeToken(t.value);
        if (re.hasMatch(l.productName) || re.hasMatch(l.variantName)) return true;
    }
  }
  return false;
}

/// "07:30" → 450; -1 bila kosong atau rusak.
int _minuteOfDay(String hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm.trim());
  if (m == null) return -1;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return -1;
  return h * 60 + min;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Apakah promo berlaku saat [wib] (jam dinding WIB, lihat [wibWallClock]),
/// di outlet dan kanal ini, dan kuotanya masih ada. Bila tidak, alasannya
/// dalam kalimat yang bisa ditampilkan — sama dengan kalimat server.
({bool ok, String why}) promoEligible(
  Promo p,
  DateTime wib,
  int branchId,
  String channel,
  PromoUsage usage,
) {
  final q = '"${p.name}"';
  if (!p.isActive) return (ok: false, why: 'Promo $q sedang dinonaktifkan');
  if (channel == 'pickup') {
    if (!p.channelPickup) return (ok: false, why: 'Promo $q tidak berlaku untuk Web Pickup');
  } else if (!p.channelPos) {
    return (ok: false, why: 'Promo $q tidak berlaku di kasir');
  }
  if (p.branchIds.isNotEmpty && !p.branchIds.contains(branchId)) {
    return (ok: false, why: 'Promo $q tidak berlaku di outlet ini');
  }
  final day = '${wib.year.toString().padLeft(4, '0')}-${_two(wib.month)}-${_two(wib.day)}';
  if (p.startDate.isNotEmpty && day.compareTo(p.startDate) < 0) {
    return (ok: false, why: 'Promo $q baru berlaku mulai ${p.startDate}');
  }
  if (p.endDate.isNotEmpty && day.compareTo(p.endDate) > 0) {
    return (ok: false, why: 'Promo $q sudah berakhir ${p.endDate}');
  }
  final weekday = wib.weekday % 7;
  if (!p.days.contains(weekday)) {
    return (ok: false, why: 'Promo $q tidak berlaku hari ${_weekdays[weekday]}');
  }
  final m = wib.hour * 60 + wib.minute;
  final start = _minuteOfDay(p.startTime);
  if (start >= 0 && m < start) {
    return (ok: false, why: 'Promo $q baru berlaku pukul ${p.startTime.replaceFirst(':', '.')}');
  }
  final end = _minuteOfDay(p.endTime);
  if (end >= 0 && m >= end) {
    return (ok: false, why: 'Promo $q sudah lewat jamnya (sampai ${p.endTime.replaceFirst(':', '.')})');
  }
  if (p.limitTotal > 0 && usage.total >= p.limitTotal) {
    return (ok: false, why: 'Promo $q sudah mencapai batas ${p.limitTotal} transaksi');
  }
  if (p.limitDaily > 0 && usage.today >= p.limitDaily) {
    return (ok: false, why: 'Promo $q sudah mencapai batas ${p.limitDaily} transaksi hari ini');
  }
  return (ok: true, why: '');
}

/// Cakupan beli X gratis Y: semua baris keranjang harus masuk cakupan, begitu
/// juga item gratisnya. Kosong bila boleh.
String buyFreeScopeProblem(Promo p, List<PricingLine> lines, PricingLine free) {
  if (p.scope != 'targets') return '';
  final q = '"${p.name}"';
  if (!lineInScope(p, free)) return '${free.label} tidak termasuk cakupan promo $q';
  for (final l in lines) {
    if (!lineInScope(p, l)) {
      return 'Promo $q hanya berlaku bila semua item di keranjang termasuk cakupannya; ${l.label} tidak termasuk';
    }
  }
  return '';
}

/// Potongan satu promo persen atas keranjang ini, 0 bila tidak memenuhi
/// minimal belanja atau tidak ada baris dalam cakupan. Dibulatkan ke bawah ke
/// rupiah penuh, lalu dibatasi potongan maksimal.
int percentDiscount(Promo p, List<PricingLine> lines) {
  if (p.kind != PromoKind.percent || p.percent <= 0) return 0;
  if (p.minSpend > 0 && pricingSubtotal(lines) < p.minSpend) return 0;
  var base = 0;
  for (final l in lines) {
    if (!lineInScope(p, l)) continue;
    final paid = l.qty - l.freeQty < 0 ? 0 : l.qty - l.freeQty;
    base += l.unitPrice * paid;
    if (p.includeToppings) base += l.toppingAmount;
  }
  var d = base * p.percent ~/ 100;
  if (p.maxDiscount > 0 && d > p.maxDiscount) d = p.maxDiscount;
  return d;
}

/// Hitung promo persen dan diskon manual di atas potongan beli X gratis Y
/// ([freeDiscount]) yang sudah dihitung pemanggil.
///
/// - Paling banyak satu promo persen; bila beberapa cocok, potongan terbesar
///   (seri → id terkecil).
/// - Bila kasir memakai beli X gratis Y, promo persen ikut hanya bila promo
///   persen itu dan semua beli X gratis Y yang dipilih boleh digabung. Kalau
///   tidak, promo persen dilepas dan dilaporkan di `droppedPercent`.
/// - Diskon manual tidak bisa bersama promo apa pun. Batasnya persen dari
///   subtotal, juga untuk diskon rupiah, dan alasannya wajib.
PricingResult evaluatePricing({
  required DateTime wib,
  required int branchId,
  String channel = 'pos',
  required List<PricingLine> lines,
  required List<Promo> promos,
  Map<int, PromoUsage> usage = const {},
  List<int> chosenBuyFree = const [],
  int freeDiscount = 0,
  ManualDiscountInput? manual,
}) {
  final subtotal = pricingSubtotal(lines);

  final byId = {for (final p in promos) p.id: p};
  var stackOK = true;
  for (final id in chosenBuyFree) {
    final p = byId[id];
    if (p == null || !p.stackable) stackOK = false;
  }

  final compatible = <(Promo, int)>[];
  final all = <(Promo, int)>[];
  for (final p in promos) {
    if (p.kind != PromoKind.percent) continue;
    if (!promoEligible(p, wib, branchId, channel, usage[p.id] ?? PromoUsage.none).ok) continue;
    final d = percentDiscount(p, lines);
    if (d <= 0) continue;
    all.add((p, d));
    if (chosenBuyFree.isEmpty || (stackOK && p.stackable)) compatible.add((p, d));
  }
  AppliedPromo? best(List<(Promo, int)> cs) {
    if (cs.isEmpty) return null;
    cs.sort((a, b) => a.$2 != b.$2 ? b.$2.compareTo(a.$2) : a.$1.id.compareTo(b.$1.id));
    return AppliedPromo(id: cs.first.$1.id, name: cs.first.$1.name, discount: cs.first.$2);
  }

  final percent = best(compatible);
  final dropped = percent == null ? best(all) : null;
  final promoTotal = freeDiscount + (percent?.discount ?? 0);

  final violations = <PricingViolation>[];
  var manualDiscount = 0;
  var manualPercent = 0;
  if (manual != null && manual.value != 0) {
    if (promoTotal > 0) {
      violations.add(const PricingViolation(PricingViolation.discountWithPromo,
          'Transaksi ini sudah memakai promo; diskon manual tidak bisa ditambahkan'));
    } else if (!manual.hasReason) {
      violations.add(const PricingViolation(PricingViolation.discountReason, 'Pilih alasan diskon dulu'));
    }
    switch (manual.kind) {
      case 'percent':
        if (manual.value < 0 || manual.value > 100) {
          violations.add(PricingViolation(
              PricingViolation.discountInvalid, 'Diskon ${manual.value}% tidak masuk akal'));
          break;
        }
        manualDiscount = subtotal * manual.value ~/ 100;
        manualPercent = manual.value;
        if (manual.value > manual.limitPct) {
          violations.add(PricingViolation(PricingViolation.discountLimit,
              'Diskon ${manual.value}% melebihi batas akunmu ${manual.limitPct}%'));
        }
      case 'amount':
        manualDiscount = manual.value;
        final limit = subtotal * manual.limitPct ~/ 100;
        if (manualDiscount < 0 || manualDiscount > subtotal) {
          violations.add(PricingViolation(PricingViolation.discountInvalid,
              'Diskon Rp$manualDiscount melebihi subtotal Rp$subtotal'));
        } else if (manualDiscount > limit) {
          violations.add(PricingViolation(PricingViolation.discountLimit,
              'Diskon Rp$manualDiscount melebihi batas akunmu ${manual.limitPct}% (Rp$limit dari subtotal Rp$subtotal)'));
        }
      default:
        violations.add(const PricingViolation(
            PricingViolation.discountInvalid, 'Bentuk diskon harus persen atau rupiah'));
    }
  }

  var total = subtotal - promoTotal - manualDiscount;
  if (total < 0) total = 0;
  return PricingResult(
    subtotal: subtotal,
    percent: percent,
    droppedPercent: dropped,
    freeDiscount: freeDiscount,
    manualDiscount: manualDiscount,
    manualPercent: manualPercent,
    total: total,
    violations: violations,
  );
}
