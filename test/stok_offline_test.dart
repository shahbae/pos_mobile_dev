import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_mobile/core/offline_stock.dart';
import 'package:pos_mobile/data/local/catalog_store.dart';
import 'package:pos_mobile/data/local/kasir_local_db.dart';
import 'package:pos_mobile/data/local/outbox_store.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/presentation/providers/offline_stock_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

// Stok offline (revisi owner 28 Nov 2026): selama offline HP menghitung sendiri
// stok yang terpakai dan menolak penjualan yang stoknya tidak cukup. Contoh
// owner: gula 300 g, offline, jual yang butuh 200 g → boleh; jual lagi yang
// butuh 200 g → sisa 100 g, ditolak.

final Map<String, dynamic> _fixture = Map<String, dynamic>.from(
  (jsonDecode(File('test/fixtures/pos_catalog.json').readAsStringSync()) as Map)['data'] as Map,
);

/// Aturan potong: Es Teh Jumbo (varian 1) butuh gula 200 g + teh 15,5 g; Kopi
/// Susu (tanpa varian) butuh susu 0,025 l. Jelly 1 per porsi, Oreo 0,5.
/// Jumbo memakai Cup 16 oz (wadah) + sedotan besar; item tanpa varian memakai
/// kantong. Server sudah mencari kemasan ini per varian dan menyaring barang
/// nonaktif, jadi HP tinggal memakainya.
final Map<String, dynamic> _rules = {
  'product_recipes': [
    {'product_id': 2, 'material_id': 5, 'qty': '0.025'},
  ],
  'variant_recipes': [
    {'variant_id': 1, 'material_id': 3, 'qty': '200'},
    {'variant_id': 1, 'material_id': 4, 'qty': '15.5'},
  ],
  'topping_usage': [
    {'topping_id': 1, 'usage_qty': '0.5'},
    {'topping_id': 2, 'usage_qty': '1'},
  ],
  'variant_packaging': [
    {'variant_id': 1, 'item_type': 'plastic', 'item_id': 8, 'qty': 1, 'wadah': true},
    {'variant_id': 1, 'item_type': 'sedotan', 'item_id': 2, 'qty': 1, 'wadah': false},
  ],
  'plain_packaging': [
    {'item_type': 'plastic', 'item_id': 1, 'qty': 1, 'wadah': false},
  ],
  'items': [
    {'item_type': 'material', 'item_id': 3, 'name': 'Gula Putih', 'unit': 'gram'},
    {'item_type': 'material', 'item_id': 4, 'name': 'Teh', 'unit': 'gram'},
    {'item_type': 'material', 'item_id': 5, 'name': 'Susu', 'unit': 'liter'},
    {'item_type': 'topping', 'item_id': 1, 'name': 'Oreo'},
    {'item_type': 'topping', 'item_id': 2, 'name': 'Jelly'},
    {'item_type': 'plastic', 'item_id': 1, 'name': 'Kantong'},
    {'item_type': 'plastic', 'item_id': 8, 'name': 'Cup 16 oz'},
    {'item_type': 'sedotan', 'item_id': 1, 'name': 'Sedotan kecil'},
    {'item_type': 'sedotan', 'item_id': 2, 'name': 'Sedotan besar'},
  ],
};

List<Map<String, dynamic>> _stock({String gula = '300'}) => [
  {'item_type': 'material', 'item_id': 3, 'qty': gula},
  {'item_type': 'material', 'item_id': 4, 'qty': '1000'},
  {'item_type': 'material', 'item_id': 5, 'qty': '5'},
  {'item_type': 'topping', 'item_id': 1, 'qty': '20'},
  {'item_type': 'topping', 'item_id': 2, 'qty': '20'},
  {'item_type': 'plastic', 'item_id': 1, 'qty': '50'},
  {'item_type': 'plastic', 'item_id': 8, 'qty': '50'},
  {'item_type': 'sedotan', 'item_id': 1, 'qty': '50'},
  {'item_type': 'sedotan', 'item_id': 2, 'qty': '50'},
];

PosCatalogFetch _fetch({
  required DateTime at,
  String gula = '300',
  bool withRules = true,
  bool withStock = true,
  bool unchanged = false,
}) {
  final data = jsonDecode(jsonEncode(_fixture)) as Map<String, dynamic>;
  data['cashier'] = {'id': 5, 'name': 'Alam Kasir'};
  data['shift'] = {'id': 8, 'shift_name': 'Shift 1', 'shift_date': '2026-10-10', 'last_queue_no': 41};
  data['server_time'] = at.toUtc().toIso8601String();
  data['offline_sales_enabled'] = true;
  if (withRules) data['stock_rules'] = _rules;
  if (withStock) data['stock'] = _stock(gula: gula);
  if (unchanged) data['unchanged'] = true;
  return PosCatalogFetch.fromJson(data, fetchedAt: at);
}

final PosCatalog _catalog = _fetch(at: DateTime(2026, 10, 10, 13)).catalog!;
final StockRules _stockRules = _catalog.stockRules!;
Product get _teh => _catalog.products.firstWhere((p) => p.name == 'Es Teh');
Product get _kopi => _catalog.products.firstWhere((p) => p.name == 'Kopi Susu');

int _u(String qty) => parseStockQty(qty)!;

Map<String, int> _needs(Map<String, dynamic> request) => stockNeeds(_stockRules, request);

class _Server implements ProductTransactionRepository {
  bool online = false;
  final List<String> sent = [];
  Object? rejectNext;

  @override
  Future<bool> ping() async => online;

  @override
  Future<String> sendOffline(Map<String, dynamic> payload) async {
    if (!online) {
      throw const TransactionSubmitException('tidak bisa menghubungi server', rejected: false, unreachable: true);
    }
    final reject = rejectNext;
    if (reject != null) {
      rejectNext = null;
      throw reject;
    }
    sent.add(payload['client_ref'] as String);
    return 'INV-${sent.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('angka stok', () {
    test('desimal dari server dibaca tepat, tanpa galat pembulatan', () {
      expect(parseStockQty('300'), 3000000);
      expect(parseStockQty('300.0000'), 3000000);
      expect(parseStockQty('0.025'), 250);
      expect(parseStockQty('15.5'), 155000);
      expect(parseStockQty('-0.5'), -5000);
      expect(parseStockQty(2), 20000);
      expect(parseStockQty('abc'), isNull);
      // 0,1 × 3 = 0,3 persis — dengan double ini 0,30000000000000004 > 0,3.
      expect(parseStockQty('0.1')! * 3, parseStockQty('0.3'));
    });

    test('ditulis seperti pesan server', () {
      expect(formatStockQty(1000000), '100');
      expect(formatStockQty(5000), '0.5');
      expect(formatStockQty(155000), '15.5');
      expect(formatStockQty(250), '0.025');
      expect(formatStockQty(0), '0');
    });

  });

  group('kebutuhan satu penjualan (sama dengan Create di server)', () {
    test('resep varian, topping per gelas, kemasan otomatis, tumbler, pilihan kasir', () {
      final needs = _needs({
        'items': [
          {
            'product_id': 1,
            'variant_id': 1,
            'qty': 2,
            'tumbler_qty': 1,
            'free_toppings': [
              {'topping_id': 2, 'qty': 1},
            ],
            'extra_toppings': [
              {'topping_id': 1, 'qty': 2},
            ],
          },
          {'product_id': 2, 'qty': 1},
        ],
        'plastics': [
          {'plastic_id': 1, 'qty': 1},
        ],
        'sedotans': [
          {'sedotan_id': 1, 'qty': 1},
        ],
      });

      expect(needs, {
        'material:3': _u('400'), // gula 200 × 2 gelas
        'material:4': _u('31'), // teh 15,5 × 2
        'material:5': _u('0.025'), // susu, resep produk tanpa varian
        'topping:2': _u('2'), // jelly 1 per gelas × 2 gelas × 1
        'topping:1': _u('2'), // oreo 2 per gelas × 2 gelas × 0,5
        'plastic:8': _u('1'), // cup: 2 gelas − 1 tumbler
        'sedotan:2': _u('2'), // sedotan tidak ditiadakan tumbler
        'plastic:1': _u('2'), // kantong otomatis (tanpa varian) + pilihan kasir
        'sedotan:1': _u('1'),
      });
    });

    test('baris yang sama digabung dulu, hasilnya sama', () {
      Map<String, dynamic> line(int qty, int tumbler) => {
        'product_id': 1,
        'variant_id': 1,
        'qty': qty,
        'tumbler_qty': tumbler,
      };
      expect(
        _needs({
          'items': [line(1, 1), line(2, 0)],
        }),
        _needs({
          'items': [line(3, 1)],
        }),
      );
    });

    test('varian yang tidak dikenal katalog: bahan tetap, kemasan tidak ditebak', () {
      final needs = _needs({
        'items': [
          {'product_id': 1, 'variant_id': 77, 'qty': 1},
        ],
      });
      expect(needs, isEmpty, reason: 'varian 77 tanpa resep dan tanpa nama');
    });

    test('topping tanpa pemakaian per porsi tidak memotong stok', () {
      final needs = _needs({
        'items': [
          {
            'product_id': 2,
            'qty': 1,
            'extra_toppings': [
              {'topping_id': 9, 'qty': 1},
            ],
          },
        ],
      });
      expect(needs.containsKey('topping:9'), isFalse);
    });

    test('pesan penolakan sama dengan server', () {
      final snapshot = StockSnapshot(levels: {'material:3': _u('100'), 'plastic:8': 0}, receivedAt: DateTime(2026));
      final short = stockShortages(
        rules: _stockRules,
        needs: {'material:3': _u('200'), 'plastic:8': _u('1'), 'material:5': _u('0.025'), 'sedotan:2': _u('1')},
        available: snapshot.levels,
        snapshot: snapshot,
      );
      expect(short.map((s) => s.message), [
        'Stok Gula Putih tidak cukup: tersedia 100 gram, dibutuhkan 200 gram',
        'Stok Susu belum pernah diisi di cabang ini',
        'Stok plastik Cup 16 oz tidak cukup: tersedia 0, dibutuhkan 1',
        'Stok sedotan Sedotan besar tidak cukup: tersedia 0, dibutuhkan 1',
      ]);
    });
  });

  group('tanda siap menu selama offline', () {
    test('menu yang bahannya kurang dari satu porsi jadi habis', () {
      final readiness = OfflineReadiness(_stockRules, {'material:3': _u('100'), 'material:4': _u('1000')});
      final products = readiness.apply(_catalog.products);
      final teh = products.firstWhere((p) => p.id == _teh.id);
      final kopi = products.firstWhere((p) => p.id == _kopi.id);

      expect(teh.variants.single.ready, isFalse, reason: 'Jumbo butuh gula 200 g, sisa 100 g');
      expect(teh.ready, isFalse, reason: 'satu-satunya varian habis');
      expect(kopi.ready, isFalse, reason: 'susu belum pernah diisi');

      final cukup = OfflineReadiness(_stockRules, {'material:3': _u('200'), 'material:4': _u('15.5'), 'material:5': 1});
      expect(cukup.apply(_catalog.products).every((p) => p.ready), isFalse, reason: 'susu 0,0001 < 0,025');
      final semua = OfflineReadiness(_stockRules, {
        'material:3': _u('200'),
        'material:4': _u('15.5'),
        'material:5': 250,
      });
      expect(semua.apply(_catalog.products).every((p) => p.ready), isTrue, reason: 'pas satu porsi = siap');
    });
  });

  group('katalog membawa aturan dan angka stok', () {
    test('aturan ikut potret di HP, angka stok di setiap jawaban', () {
      final fetch = _fetch(at: DateTime(2026, 10, 10, 13));
      expect(fetch.stored!.schema, 3);
      final stored = PosCatalog.fromStored(
        StoredCatalog(
          schema: fetch.stored!.schema,
          version: fetch.stored!.version,
          fetchedAt: fetch.stored!.fetchedAt,
          payload: fetch.stored!.payload,
        ),
      );
      expect(stored.stockRules, isNotNull);
      expect(stored.stockRules!.variantRecipes[1]!.length, 2);
      expect(stored.stockRules!.variantPackaging[1]!.map((r) => r.itemId), [8, 2]);
      expect(fetch.stock!.levels['material:3'], _u('300'));
      expect((jsonDecode(fetch.stored!.payload) as Map).containsKey('stock'), isFalse,
          reason: 'angka stok berubah tiap penjualan, tidak ikut potret berversi');

      final same = _fetch(at: DateTime(2026, 10, 10, 13, 1), gula: '250', unchanged: true);
      expect(same.catalog, isNull);
      expect(same.stock!.levels['material:3'], _u('250'), reason: 'stok tetap dikirim walau katalog tak berubah');
    });

    test('server lama tanpa aturan atau angka stok: kosong, bukan galat', () {
      final fetch = _fetch(at: DateTime(2026, 10, 10, 13), withRules: false, withStock: false);
      expect(fetch.catalog!.stockRules, isNull);
      expect(fetch.stock, isNull);
    });
  });

  group('menjual saat offline', () {
    late Database db;
    late OutboxStore store;
    late _Server server;
    late DateTime clock;

    setUpAll(sqfliteFfiInit);
    setUp(() async {
      db = await openKasirLocalDb(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      store = OutboxStore(Future.value(db));
      server = _Server();
      clock = DateTime(2026, 10, 10, 13);
    });
    tearDown(() => db.close());

    Future<OfflineNotifier> siap({PosCatalogFetch? fetch}) async {
      final n = OfflineNotifier(
        store: store,
        repo: server,
        branchId: 7,
        retryInterval: const Duration(days: 1),
        now: () => clock,
      );
      addTearDown(() {
        if (n.mounted) n.dispose();
      });
      await n.onCatalogAnswer(fetch ?? _fetch(at: clock));
      n.markUnreachable();
      return n;
    }

    ProductTransactionNotifier jumbo() =>
        ProductTransactionNotifier(server)..addToCart(_teh, variant: _teh.variants.single);

    Future<OfflineSale> jual(OfflineNotifier n, ProductTransactionNotifier cart, {PosCatalog? catalog}) =>
        n.record(cart: cart, catalog: catalog ?? _catalog, paid: 10000);

    test('contoh owner: 300 g, jual 200 g boleh, jual 200 g lagi ditolak', () async {
      final n = await siap();

      await jual(n, jumbo());
      final stock = await n.localStock(_catalog);
      expect(stock!.available['material:3'], _u('100'));

      final kedua = jumbo();
      await expectLater(
        jual(n, kedua),
        throwsA(
          isA<OfflineStockShort>().having(
            (e) => e.message,
            'message',
            'Stok Gula Putih tidak cukup: tersedia 100 gram, dibutuhkan 200 gram',
          ),
        ),
      );
      expect(kedua.state.items, isNotEmpty, reason: 'keranjang tidak dikosongkan saat ditolak');
      expect((await store.counts(7)).pending, 1, reason: 'yang ditolak tidak tersimpan');
    });

    test('penolakan juga berlaku untuk kemasan otomatis', () async {
      final data = _fetch(at: clock);
      // Cup tinggal 1: gelas pertama boleh, gelas kedua ditolak.
      final levels = Map<String, int>.from(data.stock!.levels)
        ..['plastic:8'] = _u('1')
        ..['material:3'] = _u('1000');
      final n = await siap(
        fetch: PosCatalogFetch(
          version: data.version,
          unchanged: false,
          receivedAt: clock,
          shift: data.shift,
          cashierId: 5,
          cashierName: 'Alam Kasir',
          stock: StockSnapshot(levels: levels, receivedAt: clock),
          catalog: data.catalog,
          stored: data.stored,
        ),
      );
      await jual(n, jumbo());
      await expectLater(
        jual(n, jumbo()),
        throwsA(
          isA<OfflineStockShort>().having(
            (e) => e.message,
            'message',
            'Stok plastik Cup 16 oz tidak cukup: tersedia 0, dibutuhkan 1',
          ),
        ),
      );
    });

    test('terkirim sesudah angka stok diterima tetap dikurangkan; angka baru tidak menghitung dua kali', () async {
      final n = await siap();
      await jual(n, jumbo());

      // Server kembali, penjualan terkirim SESUDAH angka stok terakhir diterima.
      clock = clock.add(const Duration(minutes: 5));
      server.online = true;
      await n.probe();
      expect(server.sent, hasLength(1));
      expect(
        (await n.localStock(_catalog))!.available['material:3'],
        _u('100'),
        reason: 'angka 300 g diterima sebelum penjualan itu sampai ke server',
      );

      // Jawaban katalog berikutnya sudah mencerminkannya: 100 g, tidak 0.
      clock = clock.add(const Duration(minutes: 1));
      await n.onCatalogAnswer(_fetch(at: clock, gula: '100', unchanged: true));
      expect((await n.localStock(_catalog))!.available['material:3'], _u('100'));
    });

    test('penjualan yang ditolak server tidak memotong stok di HP', () async {
      final n = await siap(
        fetch: _fetch(at: clock, gula: '400'),
      );
      await jual(n, jumbo());
      clock = clock.add(const Duration(minutes: 1));
      server
        ..online = true
        ..rejectNext = const TransactionSubmitException('ditolak', rejected: true, statusCode: 422);
      await n.probe();
      expect((await store.counts(7)).failed, 1);
      expect((await n.localStock(_catalog))!.available['material:3'], _u('400'));
    });

    test('angka stok bertahan di HP setelah aplikasi dibuka ulang', () async {
      final n = await siap();
      await jual(n, jumbo());
      n.dispose();

      final lagi = OfflineNotifier(store: store, repo: server, branchId: 7, now: () => clock);
      addTearDown(() {
        if (lagi.mounted) lagi.dispose();
      });
      expect((await lagi.localStock(_catalog))!.available['material:3'], _u('100'));
    });

    test('server lama (tanpa aturan potong): penjualan offline tidak dicek, seperti dulu', () async {
      final lama = _fetch(at: clock, withRules: false, withStock: false);
      final n = await siap(fetch: lama);
      await jual(n, jumbo(), catalog: lama.catalog);
      await jual(n, jumbo(), catalog: lama.catalog);
      expect((await store.counts(7)).pending, 2);
      expect(await n.localStock(lama.catalog!), isNull);
    });

    test('belum pernah menerima angka stok: tidak dicek', () async {
      final n = await siap(fetch: _fetch(at: clock, withStock: false));
      await jual(n, jumbo());
      await jual(n, jumbo());
      expect((await store.counts(7)).pending, 2);
    });
  });
}
