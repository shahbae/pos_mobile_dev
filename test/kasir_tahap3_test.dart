import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/core/promo_engine.dart';
import 'package:pos_mobile/data/local/outbox_store.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/data/models/topping_model.dart';
import 'package:pos_mobile/data/offline/offline_sale.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/providers/checkout_pricing_provider.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

// Tahap 3 kasir: promo persen terpasang sendiri, diskon manual, dan pesanan
// jatah. Hitungan mesinnya diuji di promo_engine_test.dart dengan kasus yang
// sama dengan server; di sini yang dijaga adalah sambungannya — katalog,
// keranjang, isi permintaan, dan nota.

final Map<String, dynamic> _answer = Map<String, dynamic>.from(
    (jsonDecode(File('test/fixtures/pos_catalog.json').readAsStringSync()) as Map)['data'] as Map);

const _branch = 7;
const _allDays = [
  {'day_of_week': 0}, {'day_of_week': 1}, {'day_of_week': 2}, {'day_of_week': 3},
  {'day_of_week': 4}, {'day_of_week': 5}, {'day_of_week': 6},
];

/// Jawaban katalog server Tahap 3: promo persen jam 14–16 di outlet 7 dengan
/// kuota 100, beli 2 gratis 1 khusus XL, satu alasan diskon, batas akun 10%.
Map<String, dynamic> _tahap3({int usageTotal = 37, int limitPct = 10}) {
  final data = jsonDecode(jsonEncode(_answer)) as Map<String, dynamic>;
  data['version'] = 'v-tahap3';
  data['promo_rules'] = [
    {
      'id': 10, 'name': 'Happy hour 15%', 'kind': 'percent', 'buy_qty': 0, 'free_qty': 0, 'percent': 15,
      'scope': 'all', 'targets': [], 'include_toppings': true, 'min_spend': 0, 'max_discount': 0,
      'start_time': '14:00', 'end_time': '16:00', 'start_date': null, 'end_date': null,
      'channel_pos': true, 'channel_pickup': false, 'limit_total': 100, 'limit_daily': 0,
      'stackable': false, 'is_active': true, 'days': _allDays, 'branches': [{'branch_id': _branch}],
    },
    {
      'id': 11, 'name': 'Beli 2 gratis 1 XL', 'kind': 'buy_free', 'buy_qty': 2, 'free_qty': 1, 'percent': 0,
      'scope': 'targets', 'targets': [{'target_type': 'size', 'target_id': 0, 'target_value': 'XL'}],
      'include_toppings': true, 'min_spend': 0, 'max_discount': 0, 'start_time': null, 'end_time': null,
      'start_date': null, 'end_date': null, 'channel_pos': true, 'channel_pickup': false,
      'limit_total': 0, 'limit_daily': 0, 'stackable': false, 'is_active': true, 'days': _allDays, 'branches': [],
    },
  ];
  data['discount_reasons'] = [
    {'id': 3, 'name': 'Komplain rasa', 'sort': 1, 'is_active': true},
  ];
  data['discount_limit_pct'] = limitPct;
  data['promo_usage'] = [
    {'promo_id': 10, 'total': usageTotal, 'today': 4},
  ];
  return data;
}

final _fetchedAt = DateTime(2026, 11, 3, 14, 0);
PosCatalogFetch _fetch([Map<String, dynamic>? data]) =>
    PosCatalogFetch.fromJson(data ?? _tahap3(), fetchedAt: _fetchedAt);

/// Jam HP sebagai saat WIB.
DateTime _wib(String hhmm) => DateTime.parse('2026-11-03T$hhmm:00+07:00');

final _kopi = Product(id: 2, name: 'Kopi Susu', categoryId: 1, purchasePrice: '0', sellingPrice: '8000');
final _thaiXL = Product(id: 5, name: 'Thai Tea XL', categoryId: 1, purchasePrice: '0', sellingPrice: '10000');
final _thaiM = Product(id: 6, name: 'Thai Tea M', categoryId: 1, purchasePrice: '0', sellingPrice: '7000');
final _oreo = Topping(id: 1, name: 'Oreo', price: 2000);
final _jelly = Topping(id: 2, name: 'Jelly', price: 1500);

/// Repo palsu yang menyimpan isi tiap permintaan.
class _CaptureRepo implements ProductTransactionRepository {
  final List<Map<String, dynamic>> bodies = [];

  @override
  Future<ProductTransactionResponse> createTransaction(ProductTransactionRequest request) async {
    bodies.add(request.toJson());
    return ProductTransactionResponse(invoiceNumber: 'INV-1', saleId: 1, success: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

CheckoutPricing _price(
  ProductTransactionNotifier n, {
  String at = '15:00',
  int branch = _branch,
  PosCatalogFetch? fetch,
}) {
  final f = fetch ?? _fetch();
  return priceCheckout(
    cart: n.state,
    catalog: f.catalog,
    branchId: branch,
    discountLimitPct: f.discountLimitPct,
    usage: f.promoUsage,
    now: _wib(at),
  );
}

/// Kopi Susu 8.000 + Kopi Susu ber-Oreo 8.000 + 2.000 = subtotal 18.000.
ProductTransactionNotifier _kopiDua(_CaptureRepo repo) => ProductTransactionNotifier(repo)
  ..addToCart(_kopi)
  ..addLineWithToppings(_kopi, extraToppings: [CartTopping(topping: _oreo)]);

void main() {
  group('katalog', () {
    test('promo_rules, alasan, batas, dan pemakaian terbaca; yang berubah-ubah tidak disimpan', () {
      final f = _fetch();
      final c = f.catalog!;
      expect(posCatalogSchema, 2);
      expect(c.promoRules.map((p) => p.id), [10, 11]);
      final happy = c.promoRules.first;
      expect([happy.kind, happy.percent, happy.startTime, happy.endTime, happy.branchIds, happy.limitTotal],
          ['percent', 15, '14:00', '16:00', [_branch], 100]);
      expect(c.promoRules[1].targets.single.value, 'XL');
      expect(c.discountReasons.single.name, 'Komplain rasa');
      expect(f.discountLimitPct, 10);
      expect(f.promoUsage[10]?.total, 37);

      final stored = jsonDecode(f.stored!.payload) as Map<String, dynamic>;
      expect(stored.keys, containsAll(['promo_rules', 'discount_reasons']));
      expect(stored.keys, isNot(contains('discount_limit_pct')));
      expect(stored.keys, isNot(contains('promo_usage')));
      expect(PosCatalog.fromStored(f.stored!).promoRules.length, 2);
    });

    test('server lama tanpa promo_rules: promo lama jadi beli X gratis Y khusus XL', () {
      final c = _fetch(jsonDecode(jsonEncode(_answer)) as Map<String, dynamic>).catalog!;
      expect(c.promoRules.map((p) => p.name), ['Beli 2 Gratis 1', 'Jumat Berkah']);
      for (final p in c.promoRules) {
        expect([p.kind, p.scope, p.targets.single.type, p.targets.single.value], ['buy_free', 'targets', 'size', 'XL']);
      }
      expect(c.discountReasons, isEmpty);
    });

    test('batas diskon dan pemakaian promo diingat untuk jualan offline', () {
      const s = OfflineSession(shiftId: 1, discountLimitPct: 10, promoUsage: {10: PromoUsage(total: 37, today: 4)});
      final back = OfflineSession.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.discountLimitPct, 10);
      expect([back.promoUsage[10]?.total, back.promoUsage[10]?.today], [37, 4]);
    });
  });

  group('hitungan checkout', () {
    test('promo persen terpasang sendiri pada jam dan outletnya', () {
      final n = _kopiDua(_CaptureRepo());
      final p = _price(n);
      expect([p.result.subtotal, p.result.percent?.id, p.result.percent?.discount, p.total], [18000, 10, 2700, 15300]);
      expect(p.blockers, isEmpty);

      expect(_price(n, at: '16:00').result.percent, isNull, reason: 'jam selesai tidak termasuk');
      expect(_price(n, branch: 8).result.percent, isNull, reason: 'outlet lain');
      expect(_price(n, fetch: _fetch(_tahap3(usageTotal: 100))).result.percent, isNull, reason: 'kuota habis');
    });

    test('baris digabung per produk + varian seperti server', () {
      final n = _kopiDua(_CaptureRepo());
      final lines = pricingLinesOf(n.state);
      expect(lines, hasLength(1));
      expect([lines.single.qty, lines.single.unitPrice, lines.single.toppingAmount], [2, 8000, 2000]);
    });

    test('diskon manual dalam batas, melewati batas, dan tanpa alasan aktif', () {
      final n = _kopiDua(_CaptureRepo());
      n.setManualDiscount(const ManualDiscount(kind: 'percent', value: 10, reasonId: 3, reasonName: 'Komplain rasa'));
      var p = _price(n, at: '17:00');
      expect([p.result.manualDiscount, p.total, p.blockers], [1800, 16200, isEmpty]);

      n.setManualDiscount(const ManualDiscount(kind: 'amount', value: 2000, reasonId: 3, reasonName: 'Komplain rasa'));
      p = _price(n, at: '17:00');
      expect(p.blockers, ['Diskon Rp2000 melebihi batas akunmu 10% (Rp1800 dari subtotal Rp18000)']);

      n.setManualDiscount(const ManualDiscount(kind: 'amount', value: 1000, reasonId: 99, reasonName: 'Dihapus'));
      expect(_price(n, at: '17:00').blockers, ['Pilih alasan diskon dulu']);
    });

    test('diskon manual tidak bisa bersama promo persen yang sedang terpasang', () {
      final n = _kopiDua(_CaptureRepo())
        ..setManualDiscount(const ManualDiscount(kind: 'amount', value: 1000, reasonId: 3, reasonName: 'Komplain rasa'));
      final p = _price(n);
      expect(p.hasPromo, isTrue);
      expect(p.blockers, ['Transaksi ini sudah memakai promo; diskon manual tidak bisa ditambahkan']);
    });

    test('akun berbatas 0% tidak bisa memberi diskon', () {
      final n = _kopiDua(_CaptureRepo());
      expect(_price(n, fetch: _fetch(_tahap3(limitPct: 0))).canDiscount, isFalse);
      expect(_price(n).canDiscount, isTrue);
    });

    test('beli 2 gratis 1 XL yang tidak boleh digabung melepas promo persen', () {
      final f = _fetch();
      final n = ProductTransactionNotifier(_CaptureRepo())
        ..addToCart(_thaiXL)
        ..addToCart(_thaiXL)
        ..selectPromo(f.catalog!.promoRules[1])
        ..setPromoFreeItem(_thaiXL, qty: 1);
      final p = _price(n, fetch: f);
      expect(p.buyFreePromos.map((x) => x.id), [11]);
      expect([p.result.subtotal, p.result.freeDiscount, p.result.percent, p.result.droppedPercent?.id, p.total],
          [30000, 10000, null, 10, 20000]);
      expect(p.blockers, isEmpty);
    });

    test('cakupan XL: satu item M di keranjang membuat bonusnya ditolak', () {
      final f = _fetch();
      final n = ProductTransactionNotifier(_CaptureRepo())
        ..addToCart(_thaiXL)
        ..addToCart(_thaiM)
        ..selectPromo(f.catalog!.promoRules[1])
        ..setPromoFreeItem(_thaiXL, qty: 1);
      expect(_price(n, fetch: f).buyFreeProblem, contains('Thai Tea M tidak termasuk'));
    });

    test('memilih beli X gratis Y melepas diskon manual', () {
      final n = ProductTransactionNotifier(_CaptureRepo())
        ..addToCart(_thaiXL)
        ..setManualDiscount(const ManualDiscount(kind: 'amount', value: 500, reasonId: 3, reasonName: 'x'))
        ..selectPromo(_fetch().catalog!.promoRules[1]);
      expect(n.state.manualDiscount, isNull);
    });
  });

  group('isi permintaan', () {
    test('penjualan membawa versi hitungan, total yang dilihat pembeli, dan promo persennya', () async {
      final repo = _CaptureRepo();
      final n = _kopiDua(repo);
      await n.submitTransaction(paymentMethod: 'CASH', paid: 20000, pricing: _price(n).result);
      final body = repo.bodies.single;
      expect([body['pricing_version'], body['expected_total'], body['percent_promo_id']], [2, 15300, 10]);
      expect(body.containsKey('discount_kind'), isFalse);
    });

    test('diskon manual dikirim sebagai bentuk, nilai, dan alasan', () async {
      final repo = _CaptureRepo();
      final n = _kopiDua(repo)
        ..setManualDiscount(const ManualDiscount(kind: 'percent', value: 10, reasonId: 3, reasonName: 'Komplain rasa'));
      await n.submitTransaction(paymentMethod: 'CASH', paid: 20000, pricing: _price(n, at: '17:00').result);
      final body = repo.bodies.single;
      expect([body['discount_kind'], body['discount_value'], body['discount_reason_id'], body['expected_total']],
          ['percent', 10, 3, 16200]);
      expect(body.containsKey('percent_promo_id'), isFalse);
    });

    test('pesanan jatah: penerima, tanpa promo/bonus/diskon, total harga menu', () async {
      final repo = _CaptureRepo();
      final n = ProductTransactionNotifier(repo)
        ..addToCart(_thaiXL)
        ..addToCart(_thaiXL)
        ..selectPromo(_fetch().catalog!.promoRules[1])
        ..setPromoFreeItem(_thaiXL, qty: 1);
      await n.submitAllowance(recipientUserId: 6);
      final body = repo.bodies.single;
      expect([body['sale_type'], body['recipient_user_id'], body['payment_method'], body['expected_total']],
          ['allowance', 6, 'allowance', 20000]);
      expect(body.containsKey('promo_free_items'), isFalse);
      expect((body['items'] as List).single['qty'], 2, reason: 'bonus tidak ikut');
      expect(n.state.lastResponse?.invoiceNumber, 'INV-1');
    });

    test('jatah paling banyak 2 topping per minuman', () {
      final n = ProductTransactionNotifier(_CaptureRepo())
        ..addLineWithToppings(_kopi, freeToppings: [CartTopping(topping: _jelly)], extraToppings: [CartTopping(topping: _oreo)]);
      expect(allowanceToppingProblem(n.state), isNull);
      n.addLineWithToppings(_thaiXL, extraToppings: [CartTopping(topping: _oreo, qty: 2), CartTopping(topping: _jelly)]);
      expect(allowanceToppingProblem(n.state), 'Minuman jatah paling banyak 2 topping; Thai Tea XL berisi 3 topping');
    });
  });

  group('offline', () {
    OutboxDraft draft(ProductTransactionNotifier n, PricingResult pricing) => buildOfflineSale(
          cart: n.state,
          pricing: pricing,
          context: OfflineSaleContext(
            shiftId: 8, cashierId: 5, cashierName: 'Kiki', deviceId: 'hp-uji',
            catalog: _fetch().catalog!, occurredAt: _wib('15:00'),
          ),
          numbers: const OfflineNumbers(noteSeq: 1, queueNo: 3),
          idempotencyKey: 'kunci',
          paid: 20000,
        );

    test('promo persen ikut di muatan dan nota offline', () {
      final n = _kopiDua(_CaptureRepo());
      final d = draft(n, _price(n).result);
      final payload = jsonDecode(d.payload) as Map<String, dynamic>;
      expect([payload['pricing_version'], payload['percent_promo_id'], payload['total']], [2, 10, 15300]);
      final r = Receipt.fromJson(jsonDecode(d.receipt) as Map<String, dynamic>);
      expect([r.subtotal, r.promoDiscount, r.total, r.change], [18000, 2700, 15300, 4700]);
      expect(r.promos.map((p) => '${p.name}:${p.discount}'), ['Happy hour 15%:2700']);
    });

    test('diskon manual dan alasannya ikut di muatan dan nota offline', () {
      final n = _kopiDua(_CaptureRepo())
        ..setManualDiscount(const ManualDiscount(kind: 'amount', value: 1500, reasonId: 3, reasonName: 'Komplain rasa'));
      final d = draft(n, _price(n, at: '17:00').result);
      final payload = jsonDecode(d.payload) as Map<String, dynamic>;
      expect([payload['discount_kind'], payload['discount_value'], payload['discount_reason_id'], payload['total']],
          ['amount', 1500, 3, 16500]);
      final r = Receipt.fromJson(jsonDecode(d.receipt) as Map<String, dynamic>);
      expect([r.discount, r.discountReason, r.total], [1500, 'Komplain rasa', 16500]);
    });
  });

  test('nota jatah dari server terbaca sebagai JATAH', () {
    final r = Receipt.fromJson({
      'invoice_no': 'JTH-20261103-0001', 'cashier_name': 'Kiki', 'items': [], 'subtotal': 15000, 'discount': 0,
      'tax': 0, 'total': 15000, 'paid': 15000, 'change': 0, 'payment_method': 'allowance',
      'sale_type': 'allowance', 'recipient_name': 'Aenah', 'store': <String, dynamic>{},
    });
    expect([r.isAllowance, r.recipientName], [true, 'Aenah']);
    final biasa = Receipt.fromJson({
      'invoice_no': 'INV-1', 'items': [], 'subtotal': 8000, 'discount': 800, 'discount_reason': 'Komplain rasa',
      'tax': 0, 'total': 7200, 'paid': 10000, 'change': 2800, 'payment_method': 'cash', 'store': <String, dynamic>{},
    });
    expect([biasa.isAllowance, biasa.discountReason], [false, 'Komplain rasa']);
  });
}
