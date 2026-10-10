import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_mobile/data/local/kasir_local_db.dart';
import 'package:pos_mobile/data/local/outbox_store.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/data/offline/offline_sale.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

// Saat offline, hitungan di HP adalah angka resminya dan HP satu-satunya yang
// memegang penjualannya. Yang dijaga di sini: nota tidak pernah keluar untuk
// penjualan yang belum tertulis, nomornya tidak pernah kembar, dan isi yang
// dikirim ke server sama persis dengan yang ditagihkan ke pembeli.

final PosCatalog _catalog = PosCatalogFetch.fromJson(
  Map<String, dynamic>.from(
      (jsonDecode(File('test/fixtures/pos_catalog.json').readAsStringSync()) as Map)['data'] as Map),
  fetchedAt: DateTime(2026, 10, 10, 12, 40),
).catalog!;

Product get _teh => _catalog.products.firstWhere((p) => p.name == 'Es Teh');
Product get _kopi => _catalog.products.firstWhere((p) => p.name == 'Kopi Susu');

class _UnusedRepo implements ProductTransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Keranjang kasir sungguhan, dengan sedotan otomatis seperti di checkout.
ProductTransactionNotifier _kasir() {
  final n = ProductTransactionNotifier(_UnusedRepo());
  // Hanya sedotan yang benar-benar ada di server uji (lihat uji silang di bawah).
  n.setSedotanMasters(_catalog.sedotans.where((s) => s.id == 1).toList());
  return n;
}

final _at = DateTime(2026, 10, 10, 13, 5, 42);

OfflineSaleContext _context() => OfflineSaleContext(
      shiftId: 8,
      cashierId: 5,
      cashierName: 'Alam Kasir',
      deviceId: 'tablet-uji',
      catalog: _catalog,
      occurredAt: _at,
    );

OutboxDraft _draft(ProductTransactionState cart, {int paid = 50000, int noteSeq = 3, int queueNo = 44}) =>
    buildOfflineSale(
      cart: cart,
      context: _context(),
      numbers: OfflineNumbers(noteSeq: noteSeq, queueNo: queueNo),
      idempotencyKey: 'kunci-uji',
      paid: paid,
      customerName: ' Budi ',
    );

void main() {
  group('menyusun penjualan offline', () {
    test('isi permintaan membawa apa yang hanya diketahui HP', () {
      final n = _kasir()..addToCart(_teh, variant: _teh.variants.single);
      final body = jsonDecode(_draft(n.state).payload) as Map<String, dynamic>;

      expect(body['idempotency_key'], 'kunci-uji');
      expect(body['payment_method'], 'CASH');
      expect(body['client_ref'], 'OFF-20261010-0003');
      expect(body['queue_no'], 44);
      expect(body['shift_id'], 8);
      expect(body['cashier_id'], 5);
      expect(body['device_id'], 'tablet-uji');
      expect(body['total'], 7000);
      expect(body['paid'], 50000);
      expect(body['customer_name'], 'Budi');
      expect(body['catalog_version'], _catalog.version);
      // Server menolak waktu tanpa zona, jadi selalu dikirim dalam UTC.
      expect(body['occurred_at'], _at.toUtc().toIso8601String());
      expect(DateTime.parse(body['occurred_at'] as String).isAtSameMomentAs(_at), isTrue);
      expect((body['occurred_at'] as String).endsWith('Z'), isTrue);
    });

    test('harga yang ditagih ikut di tiap baris dan topping tambahan', () {
      final oreo = _catalog.toppings.firstWhere((t) => t.name == 'Oreo');
      final jelly = _catalog.toppings.firstWhere((t) => t.name == 'Jelly');
      final n = _kasir()
        ..addLineWithToppings(_teh,
            variant: _teh.variants.single,
            quantity: 2,
            freeToppings: [CartTopping(topping: jelly)],
            extraToppings: [CartTopping(topping: oreo)]);
      final item = ((jsonDecode(_draft(n.state).payload) as Map)['items'] as List).single as Map;

      expect(item['unit_price'], 7000);
      expect((item['extra_toppings'] as List).single, {'topping_id': oreo.id, 'qty': 1, 'price': 2000});
      expect((item['free_toppings'] as List).single, {'topping_id': jelly.id, 'qty': 1},
          reason: 'topping gratis tidak punya harga untuk ditagih');
      // (7000 + 2000) × 2 gelas
      expect((jsonDecode(_draft(n.state).payload) as Map)['total'], 18000);
    });

    test('bonus promo: masuk sebagai baris berharga, lalu dipotong promonya', () {
      final promo = _catalog.promos.firstWhere((p) => p.name == 'Beli 2 Gratis 1');
      final n = _kasir()
        ..addToCart(_teh, variant: _teh.variants.single)
        ..addToCart(_teh, variant: _teh.variants.single)
        ..selectPromo(promo)
        ..setPromoFreeItem(_teh, variant: _teh.variants.single, qty: 1);
      final draft = _draft(n.state);
      final body = jsonDecode(draft.payload) as Map<String, dynamic>;

      expect(body['total'], 14000, reason: 'yang dibayar hanya dua gelas');
      expect((body['items'] as List).map((i) => (i as Map)['unit_price']), [7000, 7000]);
      expect((body['items'] as List).map((i) => (i as Map)['qty']), [2, 1]);
      expect((body['promo_free_items'] as List).single,
          containsPair('promo_id', promo.id));

      final receipt = Receipt.fromJson(jsonDecode(draft.receipt) as Map<String, dynamic>);
      expect(receipt.subtotal, 21000);
      expect(receipt.promoDiscount, 7000);
      expect(receipt.total, 14000);
      expect(receipt.promos.single.name, 'Beli 2 Gratis 1');
    });

    test('nota: nomor lokal, antrean, kembalian, estimasi, dan kepala toko', () {
      final n = _kasir()
        ..addToCart(_teh, variant: _teh.variants.single)
        ..addToCart(_teh, variant: _teh.variants.single)
        ..addToCart(_kopi);
      final receipt = Receipt.fromJson(jsonDecode(_draft(n.state, paid: 25000).receipt) as Map<String, dynamic>);

      expect(receipt.invoiceNo, 'OFF-20261010-0003');
      expect(receipt.queueNo, 44);
      expect(receipt.cashierName, 'Alam Kasir');
      expect(receipt.customerName, 'Budi');
      expect(receipt.total, 22000);
      expect(receipt.paid, 25000);
      expect(receipt.change, 3000);
      expect(receipt.isCashPayment, isTrue);
      expect(receipt.store.name, 'Cabang Uji');
      expect(receipt.store.footerNote, 'Terima kasih');
      expect(receipt.items.map((i) => i.displayName), ['Es Teh - Jumbo', 'Kopi Susu']);
      expect(receipt.createdAt!.isAtSameMomentAs(_at), isTrue);
      // 2 gelas × 2 menit + 1 gelas × 3 menit, dari menit kejadian.
      expect(receipt.estimatedPrepMinutes, 7);
      expect(receipt.estimatedReadyAt!.isAtSameMomentAs(DateTime(2026, 10, 10, 13, 12)), isTrue);
      expect(receipt.sedotans.single.qty, 3, reason: 'sedotan otomatis ikut di nota');
    });

    test('tanpa waktu pembuatan tidak ada estimasi', () {
      final noPrep = Product(id: 9, name: 'Air Mineral', purchasePrice: '0', sellingPrice: '3000');
      final n = _kasir()..addToCart(noPrep);
      final receipt = Receipt.fromJson(jsonDecode(_draft(n.state).receipt) as Map<String, dynamic>);

      expect(receipt.hasEstimate, isFalse);
    });

    test('nomor nota mengikuti tanggal kejadian', () {
      expect(offlineClientRef(DateTime(2026, 1, 5), 12), 'OFF-20260105-0012');
      expect(offlineClientRef(DateTime(2026, 12, 31, 23, 59), 1), 'OFF-20261231-0001');
    });
  });

  group('antrean kirim di HP (SQLite)', () {
    late Database db;
    late OutboxStore store;

    setUpAll(sqfliteFfiInit);
    setUp(() async {
      db = await openKasirLocalDb(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      store = OutboxStore(Future.value(db));
    });
    tearDown(() => db.close());

    Future<OutboxEntry> record(String key, {int branchId = 7, int shiftId = 8, DateTime? at}) {
      return store.record(
        branchId: branchId,
        shiftId: shiftId,
        idempotencyKey: key,
        occurredAt: at ?? _at,
        total: 7000,
        build: (numbers) => OutboxDraft(
          clientRef: offlineClientRef(at ?? _at, numbers.noteSeq),
          payload: jsonEncode({'queue_no': numbers.queueNo}),
          receipt: '{}',
        ),
      );
    }

    test('nomor nota dan antrean berurutan, penjualan tersimpan sebagai menunggu', () async {
      final a = await record('k1');
      final b = await record('k2');

      expect(a.clientRef, 'OFF-20261010-0001');
      expect(b.clientRef, 'OFF-20261010-0002');
      expect(jsonDecode(a.payload), {'queue_no': 1});
      expect(jsonDecode(b.payload), {'queue_no': 2});
      expect(a.isPending, isTrue);
      expect((await store.pending(7)).map((e) => e.idempotencyKey), ['k1', 'k2']);
    });

    test('antrean melanjutkan nomor terakhir dari server', () async {
      await store.observeQueueNo(8, 41);
      await store.observeQueueNo(8, 12); // nomor lama tidak memundurkan penghitung

      final e = await record('k1');

      expect(jsonDecode(e.payload), {'queue_no': 42});
      expect(await store.lastQueueNo(8), 42);
    });

    test('bayar ditekan dua kali: satu baris, tanpa membakar nomor', () async {
      final a = await record('sama');
      final b = await record('sama');
      final c = await record('lain');

      expect(b.id, a.id);
      expect(b.clientRef, a.clientRef);
      expect(c.clientRef, 'OFF-20261010-0002');
      expect(await store.pending(7), hasLength(2));
    });

    test('nomor nota mulai lagi dari 1 esok harinya, antrean per shift', () async {
      await record('k1');
      final besok = await record('k2', at: DateTime(2026, 10, 11, 8), shiftId: 9);

      expect(besok.clientRef, 'OFF-20261011-0001');
      expect(jsonDecode(besok.payload), {'queue_no': 1});
    });

    test('tiap cabang punya antrean kirimnya sendiri', () async {
      await record('a', branchId: 7);
      await record('b', branchId: 8);

      expect((await store.pending(7)).single.idempotencyKey, 'a');
      expect((await store.pending(8)).single.idempotencyKey, 'b');
      expect(await store.pendingAnywhere(), 2);
    });

    test('terkirim, ditolak, dan dicoba lagi', () async {
      final a = await record('k1');
      final b = await record('k2');
      final c = await record('k3');

      await store.markSent(a.id, invoiceNo: 'INV-20261010-0044', at: DateTime(2026, 10, 10, 15));
      await store.markFailed(b.id, 'produk tidak ditemukan');
      await store.noteAttempt(c.id, 'tidak bisa menghubungi server');

      var counts = await store.counts(7);
      expect((counts.pending, counts.failed), (1, 1));
      final list = await store.list(7);
      expect(list.firstWhere((e) => e.id == a.id).invoiceNo, 'INV-20261010-0044');
      expect(list.firstWhere((e) => e.id == b.id).lastError, 'produk tidak ditemukan');
      final waiting = list.firstWhere((e) => e.id == c.id);
      expect(waiting.isPending, isTrue, reason: 'belum ada jawaban berarti tetap menunggu');
      expect(waiting.attempts, 1);

      await store.retry(b.id);
      counts = await store.counts(7);
      expect((counts.pending, counts.failed), (2, 0));
      expect((await store.pending(7)).map((e) => e.id), [b.id, c.id], reason: 'urutan lama dipertahankan');
    });

    test('pembersihan hanya menyentuh yang sudah lama terkirim', () async {
      final lama = await record('lama');
      final baru = await record('baru');
      final menunggu = await record('menunggu');
      final ditolak = await record('ditolak');
      await store.markSent(lama.id, invoiceNo: 'INV-1', at: DateTime(2026, 10, 1));
      await store.markSent(baru.id, invoiceNo: 'INV-2', at: DateTime(2026, 10, 10));
      await store.markFailed(ditolak.id, 'rusak');

      final removed = await store.purgeSent(DateTime(2026, 10, 3));

      expect(removed, 1);
      expect((await store.list(7)).map((e) => e.id), unorderedEquals([baru.id, menunggu.id, ditolak.id]));
    });

    test('id perangkat dibuat sekali lalu tetap', () async {
      final a = await store.deviceId();
      final b = await store.deviceId();

      expect(a, hasLength(32));
      expect(b, a);
    });

    test('DB versi 1 (hanya katalog) naik ke versi 2 tanpa kehilangan potret', () async {
      final path = '${Directory.systemTemp.createTempSync('kasir-db').path}/kasir_local.db';
      addTearDown(() => File(path).parent.deleteSync(recursive: true));
      final v1 = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (d, _) => d.execute('CREATE TABLE catalog (branch_id INTEGER PRIMARY KEY,'
                  ' schema INTEGER NOT NULL, version TEXT NOT NULL, fetched_at INTEGER NOT NULL, payload TEXT NOT NULL)')));
      await v1.insert('catalog', {'branch_id': 7, 'schema': 1, 'version': 'v', 'fetched_at': 1, 'payload': '{}'});
      await v1.close();

      final v2 = await openKasirLocalDb(factory: databaseFactoryFfi, path: path);
      addTearDown(v2.close);

      expect(await v2.query('catalog'), hasLength(1));
      final upgraded = OutboxStore(Future.value(v2));
      expect(await upgraded.pending(7), isEmpty);
      expect(await upgraded.deviceId(), isNotEmpty);
    });
  });

  // Dijalankan terpisah oleh uji silang ke server lokal (lihat pesan commit):
  // menulis isi permintaan buatan app supaya bisa dikirim ke be-pos sungguhan
  // dan dibandingkan totalnya.
  test('isi permintaan untuk uji silang dengan server', () {
    final out = Platform.environment['OFFLINE_PAYLOAD_OUT'];
    final oreo = _catalog.toppings.firstWhere((t) => t.name == 'Oreo');
    final jelly = _catalog.toppings.firstWhere((t) => t.name == 'Jelly');
    final kantong = _catalog.plastics.firstWhere((p) => p.name == 'Kantong');
    final promo = _catalog.promos.firstWhere((p) => p.name == 'Beli 2 Gratis 1');
    final jumbo = _teh.variants.single;

    final carts = <String, ProductTransactionNotifier>{
      'polos': _kasir()..addToCart(_teh, variant: jumbo),
      'topping gratis dan tambahan, kantong': _kasir()
        ..addLineWithToppings(_teh,
            variant: jumbo,
            quantity: 3,
            freeToppings: [CartTopping(topping: jelly)],
            extraToppings: [CartTopping(topping: oreo, qty: 2)])
        ..setPlastic(kantong, qty: 1),
      'dua baris varian sama, topping beda': _kasir()
        ..addLineWithToppings(_teh, variant: jumbo, quantity: 1, extraToppings: [CartTopping(topping: oreo)])
        ..addLineWithToppings(_teh, variant: jumbo, quantity: 2, extraToppings: [CartTopping(topping: jelly)])
        ..addToCart(_teh, variant: jumbo),
      'promo beli 2 gratis 1': _kasir()
        ..addToCart(_teh, variant: jumbo)
        ..addToCart(_teh, variant: jumbo)
        ..selectPromo(promo)
        ..setPromoFreeItem(_teh, variant: jumbo, qty: 1),
      'promo dua kali lipat dengan topping tambahan': _kasir()
        ..addLineWithToppings(_teh, variant: jumbo, quantity: 4, extraToppings: [CartTopping(topping: oreo)])
        ..selectPromo(promo)
        ..setPromoFreeItem(_teh, variant: jumbo, qty: 2),
      'tumbler': _kasir()
        ..addToCart(_teh, variant: jumbo)
        ..addToCart(_teh, variant: jumbo)
        ..setTumblerQty(1, 1),
    };

    final cases = <Map<String, dynamic>>[];
    var seq = 0;
    carts.forEach((name, n) {
      seq++;
      final draft = buildOfflineSale(
        cart: n.state,
        context: _context(),
        numbers: OfflineNumbers(noteSeq: seq, queueNo: seq),
        idempotencyKey: 'silang-$seq',
        paid: n.state.total.toInt(),
      );
      final body = jsonDecode(draft.payload) as Map<String, dynamic>;
      expect(body['total'], n.state.total.toInt(), reason: name);
      cases.add({'name': name, 'app_total': n.state.total.toInt(), 'payload': body});
    });

    expect(cases, hasLength(carts.length));
    if (out != null && out.isNotEmpty) {
      File(out).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(cases));
    }
  });
}
