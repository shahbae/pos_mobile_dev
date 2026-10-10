import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_mobile/data/local/kasir_local_db.dart';
import 'package:pos_mobile/data/local/outbox_store.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

// Mode offline memegang uang yang belum tercatat di server. Yang dijaga di
// sini: penjualan tidak pernah hilang, tidak pernah terkirim dobel atau
// menyalip urutan, dan satu penjualan yang rusak tidak menahan yang lain.

final Map<String, dynamic> _answer = Map<String, dynamic>.from(
    (jsonDecode(File('test/fixtures/pos_catalog.json').readAsStringSync()) as Map)['data'] as Map);

final _deviceNow = DateTime(2026, 10, 10, 13, 5, 42);

PosCatalogFetch _fetch({Map<String, dynamic>? shift, bool noShift = false, DateTime? serverTime}) {
  final data = jsonDecode(jsonEncode(_answer)) as Map<String, dynamic>;
  data['cashier'] = {'id': 5, 'name': 'Alam Kasir'};
  data['shift'] = noShift
      ? null
      : (shift ?? {'id': 8, 'shift_name': 'Shift 1', 'shift_date': '2026-10-10', 'last_queue_no': 41});
  data['server_time'] = (serverTime ?? _deviceNow).toUtc().toIso8601String();
  return PosCatalogFetch.fromJson(data, fetchedAt: _deviceNow);
}

final PosCatalog _catalog = _fetch().catalog!;
Product get _teh => _catalog.products.firstWhere((p) => p.name == 'Es Teh');

const _putus = TransactionSubmitException('tidak bisa menghubungi server', rejected: false, unreachable: true);
const _galatServer = TransactionSubmitException('server galat', rejected: false);
const _ditolak =
    TransactionSubmitException('Produk tidak ditemukan (id: [99])', rejected: true, statusCode: 422);
const _sesiHabis = TransactionSubmitException('unauthorized', rejected: true, statusCode: 401);

/// Server palsu: mencatat nota yang dikirim dan menjawab sesuai antrean
/// [answers] (galat dilempar, selain itu diterima).
class _Server implements ProductTransactionRepository {
  bool online = true;
  final List<String> received = [];
  final List<Object?> answers = [];
  int pings = 0;

  @override
  Future<bool> ping() async {
    pings++;
    return online;
  }

  @override
  Future<String> sendOffline(Map<String, dynamic> payload) async {
    if (!online) throw _putus;
    final next = answers.isEmpty ? null : answers.removeAt(0);
    if (next != null) throw next;
    received.add(payload['client_ref'] as String);
    return 'INV-20261010-${(received.length + 40).toString().padLeft(4, '0')}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Database db;
  late OutboxStore store;
  late _Server server;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await openKasirLocalDb(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    store = OutboxStore(Future.value(db));
    server = _Server();
  });
  tearDown(() => db.close());

  OfflineNotifier notifier({int? branchId = 7}) {
    final n = OfflineNotifier(
      store: store,
      repo: server,
      branchId: branchId,
      retryInterval: const Duration(days: 1), // percobaan berkala tidak diuji di sini
      now: () => _deviceNow,
    );
    addTearDown(() {
      if (n.mounted) n.dispose();
    });
    return n;
  }

  ProductTransactionNotifier cart() =>
      ProductTransactionNotifier(server)..addToCart(_teh, variant: _teh.variants.single);

  /// Kasir yang sudah pernah terhubung: shift, kasir, dan jam server diingat.
  Future<OfflineNotifier> siap({PosCatalogFetch? fetch}) async {
    final n = notifier();
    await n.onCatalogAnswer(fetch ?? _fetch());
    return n;
  }

  Future<OfflineSale> jual(OfflineNotifier n, {ProductTransactionNotifier? keranjang, int paid = 10000}) =>
      n.record(cart: keranjang ?? cart(), catalog: _catalog, paid: paid);

  group('menyimpan penjualan', () {
    test('tersimpan dengan shift, kasir, dan antrean lanjutan; keranjang dikosongkan', () async {
      final n = await siap();
      server.online = false;
      n.markUnreachable();
      final keranjang = cart();

      final sale = await jual(n, keranjang: keranjang);

      final body = jsonDecode(sale.entry.payload) as Map<String, dynamic>;
      expect(sale.entry.clientRef, 'OFF-20261010-0001');
      expect(body['shift_id'], 8);
      expect(body['cashier_id'], 5);
      expect(body['queue_no'], 42, reason: 'melanjutkan nomor 41 dari server');
      expect(body['total'], 7000);
      expect(sale.receipt.invoiceNo, 'OFF-20261010-0001');
      expect(sale.receipt.cashierName, 'Alam Kasir');
      expect(sale.receipt.change, 3000);
      expect(keranjang.state.items, isEmpty);
      expect(keranjang.state.lastResponse!.invoiceNumber, 'OFF-20261010-0001');
      expect(n.state.pending, 1);
      expect(n.state.active, isTrue);
    });

    test('jam kejadian dikoreksi selisih jam server', () async {
      // Jam HP tertinggal 3 menit dari server.
      final n = await siap(fetch: _fetch(serverTime: _deviceNow.add(const Duration(minutes: 3))));
      server.online = false;

      final sale = await jual(n);

      expect(sale.entry.occurredAt, _deviceNow.add(const Duration(minutes: 3)));
    });

    test('ditolak dengan alasan jelas bila belum boleh atau belum bisa', () async {
      Future<String> alasan(Future<OfflineSale> Function() f) async {
        try {
          await f();
        } on OfflineUnavailable catch (e) {
          return e.message;
        }
        fail('seharusnya ditolak');
      }

      final belumTerhubung = notifier();
      expect(await alasan(() => jual(belumTerhubung)), contains('Shift belum dibuka'));

      final tanpaShift = await siap(fetch: _fetch(noShift: true));
      expect(await alasan(() => jual(tanpaShift)), contains('Shift belum dibuka'));

      final n = await siap();
      expect(await alasan(() => n.record(cart: cart(), catalog: null, paid: 7000)), contains('Menu belum pernah dimuat'));

      final off = jsonDecode(jsonEncode(_answer)) as Map<String, dynamic>..['offline_sales_enabled'] = false;
      final mati = PosCatalogFetch.fromJson(off, fetchedAt: _deviceNow).catalog!;
      expect(await alasan(() => n.record(cart: cart(), catalog: mati, paid: 7000)), contains('belum diaktifkan'));

      expect(await alasan(() => n.record(cart: ProductTransactionNotifier(server), catalog: _catalog, paid: 0)),
          contains('Keranjang kosong'));
      expect(n.state.pending, 0, reason: 'yang ditolak tidak meninggalkan baris');
    });

    test('shift ditutup: yang tersimpan tidak dipakai lagi', () async {
      final n = await siap();
      await n.forgetShift();

      expect((await n.session()).hasShift, isFalse);
      expect((await n.session()).cashierName, 'Alam Kasir', reason: 'kasirnya tetap dikenali');
    });

    test('nomor antrean dari penjualan online ikut diingat', () async {
      final n = await siap();
      await n.observeQueueNo(47);
      server.online = false;

      final sale = await jual(n);

      expect((jsonDecode(sale.entry.payload) as Map)['queue_no'], 48);
    });
  });

  group('mengirim antrean', () {
    test('jaringan kembali: terkirim berurutan, mode offline berakhir', () async {
      final n = await siap();
      server.online = false;
      n.markUnreachable();
      await jual(n);
      await jual(n);
      await jual(n);
      expect(n.state.pending, 3);

      server.online = true;
      await n.probe();

      expect(server.received, ['OFF-20261010-0001', 'OFF-20261010-0002', 'OFF-20261010-0003']);
      expect(n.state.pending, 0);
      expect(n.state.reachable, isTrue);
      expect(n.state.active, isFalse);
      final sent = await n.entries();
      expect(sent.every((e) => e.isSent && e.invoiceNo!.startsWith('INV-')), isTrue);
    });

    test('server masih tak terjangkau: tidak ada yang hilang, tetap menunggu', () async {
      final n = await siap();
      server.online = false;
      await jual(n);
      await jual(n);

      await n.probe();
      await n.flush();

      expect(server.received, isEmpty);
      expect(n.state.pending, 2);
      expect(n.state.reachable, isFalse);
      expect((await store.pending(7)).map((e) => e.clientRef), ['OFF-20261010-0001', 'OFF-20261010-0002']);
    });

    test('putus di tengah pengiriman: berhenti di situ, urutan terjaga', () async {
      final n = await siap();
      server.online = false;
      await jual(n);
      await jual(n);
      await jual(n);

      server.online = true;
      server.answers.addAll([null, _putus]); // nota 1 terkirim, nota 2 putus
      await n.flush();

      expect(server.received, ['OFF-20261010-0001']);
      expect(n.state.pending, 2);
      expect(n.state.reachable, isFalse);
      final waiting = await store.pending(7);
      expect(waiting.map((e) => e.clientRef), ['OFF-20261010-0002', 'OFF-20261010-0003']);
      expect(waiting.first.attempts, 1);
      expect(waiting.last.attempts, 0, reason: 'nota 3 tidak boleh menyalip nota 2');

      await n.flush();
      expect(server.received, ['OFF-20261010-0001', 'OFF-20261010-0002', 'OFF-20261010-0003']);
      expect(n.state.pending, 0);
    });

    test('satu penjualan ditolak server: disisihkan, yang lain tetap terkirim', () async {
      final n = await siap();
      server.online = false;
      await jual(n);
      await jual(n);
      await jual(n);

      server.online = true;
      server.answers.addAll([null, _ditolak]);
      await n.flush();

      expect(server.received, ['OFF-20261010-0001', 'OFF-20261010-0003']);
      expect(n.state.pending, 0);
      expect(n.state.failed, 1);
      final rejected = (await n.entries()).firstWhere((e) => e.isFailed);
      expect(rejected.clientRef, 'OFF-20261010-0002');
      expect(rejected.lastError, contains('Produk tidak ditemukan'));
      // Yang ditolak tidak membuat kasir terkunci di mode offline.
      expect(n.state.active, isFalse);
    });

    test('server hidup tapi galat (5xx): berhenti, bukan dianggap putus', () async {
      final n = await siap();
      server.online = false;
      await jual(n);
      await jual(n);

      server.online = true;
      server.answers.add(_galatServer);
      await n.flush();

      expect(server.received, isEmpty);
      expect(n.state.pending, 2);
      expect(n.state.reachable, isTrue);
      expect(n.state.active, isTrue, reason: 'masih ada yang menunggu');
    });

    // Sesi habis bukan salah penjualannya. Kalau ikut disisihkan, kasir harus
    // menekan "Kirim ulang" satu per satu setelah login lagi.
    test('sesi login habis (401): tetap menunggu, bukan ditolak', () async {
      final n = await siap();
      server.online = false;
      await jual(n);
      await jual(n);

      server.online = true;
      server.answers.add(_sesiHabis);
      await n.flush();

      expect(server.received, isEmpty);
      expect(n.state.pending, 2);
      expect(n.state.failed, 0);

      // Setelah login lagi, kiriman berikutnya membawa semuanya.
      await n.flush();
      expect(server.received, ['OFF-20261010-0001', 'OFF-20261010-0002']);
    });

    test('yang ditolak bisa dikirim ulang', () async {
      final n = await siap();
      server.online = false;
      await jual(n);
      server.online = true;
      server.answers.add(_ditolak);
      await n.flush();
      final rejected = (await n.entries()).single;
      expect(rejected.isFailed, isTrue);

      await n.retry(rejected.id);

      expect(server.received, ['OFF-20261010-0001']);
      expect(n.state.failed, 0);
      expect((await n.entries()).single.isSent, isTrue);
    });

    test('dua pemicu kirim bersamaan tidak mengirim dobel', () async {
      final n = await siap();
      server.online = false;
      await jual(n);
      await jual(n);

      server.online = true;
      await Future.wait([n.flush(), n.flush(), n.probe()]);

      expect(server.received, ['OFF-20261010-0001', 'OFF-20261010-0002']);
    });

    test('aplikasi dibuka lagi dengan antrean tersisa: langsung dicoba kirim', () async {
      final lama = await siap();
      server.online = false;
      lama.markUnreachable();
      await jual(lama);
      await jual(lama);
      lama.dispose();

      server.online = true;
      final baru = notifier();
      expect(baru.state.pending, 0, reason: 'belum membaca DB');
      await baru.start();

      expect(server.received, ['OFF-20261010-0001', 'OFF-20261010-0002']);
      expect(baru.state.pending, 0);
      expect(baru.state.active, isFalse);
    });

    test('server terjangkau tapi antrean belum kosong: penjualan baru ikut antre', () async {
      final n = await siap();
      server.online = false;
      await jual(n);

      // Jaringan sudah kembali, tetapi nota pertama belum sempat terkirim.
      server.online = true;
      await n.onCatalogAnswer(_fetch());
      expect(server.received, ['OFF-20261010-0001']);

      server.answers.add(_galatServer);
      final kedua = await jual(n);
      await pumpEventQueue();
      expect(kedua.entry.clientRef, 'OFF-20261010-0002');
      expect(n.state.pending, 1, reason: 'tersimpan dulu, dikirim menyusul');

      await n.flush();
      expect(server.received, ['OFF-20261010-0001', 'OFF-20261010-0002']);
    });

    test('antrean cabang lain tidak ikut terkirim', () async {
      final cabang7 = await siap();
      server.online = false;
      cabang7.markUnreachable();
      await jual(cabang7);
      cabang7.dispose();

      server.online = true;
      final cabang8 = notifier(branchId: 8);
      await cabang8.start();
      await cabang8.flush();

      expect(server.received, isEmpty, reason: 'server mencatat ke cabang yang sedang login');
      expect(cabang8.state.pending, 0);
      expect(await store.pendingAnywhere(), 1);
    });

    test('dilepas di tengah pengiriman (pindah cabang): sisanya tidak dikirim', () async {
      final n = await siap();
      server.online = false;
      n.markUnreachable();
      await jual(n);
      await jual(n);
      await jual(n);

      server.online = true;
      final sending = n.flush();
      n.dispose();
      await sending;

      expect(server.received.length, lessThan(3));
      expect(await store.pendingAnywhere(), 3 - server.received.length, reason: 'sisanya tetap utuh di HP');
    });

    test('katalog menjawab: server dianggap terjangkau dan antrean dikirim', () async {
      final n = await siap();
      server.online = false;
      n.markUnreachable();
      await jual(n);
      expect(n.state.reachable, isFalse);

      server.online = true;
      await n.onCatalogAnswer(_fetch());

      expect(n.state.reachable, isTrue);
      expect(server.received, ['OFF-20261010-0001']);
    });
  });
}
