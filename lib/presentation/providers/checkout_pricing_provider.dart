import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/promo_engine.dart';
import 'package:pos_mobile/data/models/discount_reason_model.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/presentation/providers/pos_catalog_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

/// Hitungan checkout saat ini: total yang ditunjukkan ke pembeli, promo yang
/// bisa dipilih, dan apa yang menghalangi pembayaran.
class CheckoutPricing {
  final PricingResult result;

  /// Beli X gratis Y yang berlaku sekarang di outlet ini (hari, jam, tanggal,
  /// kanal, kuota) — pilihan promo di checkout.
  final List<Promo> buyFreePromos;

  /// Kenapa beli X gratis Y yang dipilih kasir tidak bisa dipakai; null bila
  /// bisa (atau tidak ada yang dipilih).
  final String? buyFreeProblem;

  /// Batas diskon manual akun ini, persen dari subtotal. 0 = tidak bisa memberi
  /// diskon.
  final int discountLimitPct;
  final List<DiscountReason> reasons;

  const CheckoutPricing({
    required this.result,
    this.buyFreePromos = const [],
    this.buyFreeProblem,
    this.discountLimitPct = 0,
    this.reasons = const [],
  });

  int get total => result.total;

  /// Akun ini bisa memberi diskon manual sama sekali.
  bool get canDiscount => discountLimitPct > 0 && reasons.isNotEmpty;

  /// Ada promo yang sedang memotong transaksi — diskon manual tidak bisa ikut.
  bool get hasPromo => result.promoDiscount > 0;

  /// Batas diskon manual dalam rupiah untuk keranjang ini.
  int get discountLimitAmount => result.subtotal * discountLimitPct ~/ 100;

  /// Semua yang membuat pembayaran ditolak server bila dikirim. Kosong = boleh
  /// bayar.
  List<String> get blockers => [
        if (buyFreeProblem != null) buyFreeProblem!,
        for (final v in result.violations) v.message,
      ];
}

/// Hitung checkout dari keranjang dan katalog. Fungsi murni — [now] adalah jam
/// HP, dibaca sebagai jam dinding WIB.
CheckoutPricing priceCheckout({
  required ProductTransactionState cart,
  required PosCatalog? catalog,
  required int branchId,
  required int discountLimitPct,
  required Map<int, PromoUsage> usage,
  required DateTime now,
}) {
  final rules = catalog?.promoRules ?? const <Promo>[];
  final reasons = catalog?.discountReasons ?? const <DiscountReason>[];
  final wib = wibWallClock(now);
  bool eligible(Promo p) => promoEligible(p, wib, branchId, 'pos', usage[p.id] ?? PromoUsage.none).ok;

  final lines = pricingLinesOf(cart);
  final selected = cart.selectedPromo;
  final usingBuyFree = selected != null && cart.promoFreeItems.isNotEmpty;

  String? buyFreeProblem;
  if (usingBuyFree) {
    final rule = rules.where((p) => p.id == selected.id).firstOrNull;
    if (rule == null) {
      buyFreeProblem = 'Promo "${selected.name}" sudah tidak berlaku. Pilih ulang promonya.';
    } else {
      final e = promoEligible(rule, wib, branchId, 'pos', usage[rule.id] ?? PromoUsage.none);
      if (!e.ok) {
        buyFreeProblem = e.why;
      } else {
        for (final b in cart.promoFreeItems) {
          final problem = buyFreeScopeProblem(
            rule,
            lines,
            PricingLine(
              productId: b.product.id,
              variantId: b.variant?.id ?? 0,
              categoryId: b.product.categoryId ?? 0,
              productName: b.product.name,
              variantName: b.variant?.name ?? '',
              qty: b.qty,
              unitPrice: b.unitPrice.toInt(),
            ),
          );
          if (problem.isNotEmpty) {
            buyFreeProblem = problem;
            break;
          }
        }
      }
    }
  }

  final manual = cart.manualDiscount;
  final result = evaluatePricing(
    wib: wib,
    branchId: branchId,
    lines: lines,
    promos: rules,
    usage: usage,
    chosenBuyFree: usingBuyFree ? [selected.id] : const [],
    freeDiscount: usingBuyFree ? cart.promoDiscount.toInt() : 0,
    manual: manual == null
        ? null
        : ManualDiscountInput(
            kind: manual.kind,
            value: manual.value,
            limitPct: discountLimitPct,
            hasReason: reasons.any((r) => r.id == manual.reasonId),
          ),
  );

  return CheckoutPricing(
    result: result,
    buyFreePromos: rules.where((p) => p.isBuyFree && eligible(p)).toList(),
    buyFreeProblem: buyFreeProblem,
    discountLimitPct: discountLimitPct,
    reasons: reasons,
  );
}

/// Hitungan checkout yang selalu mengikuti keranjang dan katalog. Katalog
/// dicek ke server tiap menit, jadi promo yang mulai atau berakhir di tengah
/// checkout ikut terpasang atau terlepas sendiri.
final checkoutPricingProvider = Provider.autoDispose<CheckoutPricing>((ref) {
  final cart = ref.watch(productTransactionProvider);
  final catalog = ref.watch(posCatalogProvider);
  return priceCheckout(
    cart: cart,
    catalog: catalog.catalog,
    branchId: ref.watch(activeBranchIdProvider) ?? 0,
    discountLimitPct: catalog.discountLimitPct,
    usage: catalog.promoUsage,
    now: DateTime.now(),
  );
});

/// Batas topping per minuman jatah (PRD F7), topping gratis dan berbayar
/// dihitung bersama.
const allowanceMaxToppings = 2;

/// Kenapa keranjang ini tidak bisa jadi pesanan jatah; null bila bisa. Kalimat
/// yang sama dengan penolakan server.
String? allowanceToppingProblem(ProductTransactionState cart) {
  for (final i in cart.items) {
    final perGlass = [...i.freeToppings, ...i.extraToppings].fold(0, (s, t) => s + t.qty);
    if (perGlass > allowanceMaxToppings) {
      return 'Minuman jatah paling banyak $allowanceMaxToppings topping; ${i.product.name} berisi $perGlass topping';
    }
  }
  return null;
}
