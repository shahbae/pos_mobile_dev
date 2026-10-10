import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/local/catalog_store.dart';
import 'package:pos_mobile/data/local/outbox_store.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/data/repositories/pos_catalog_repository.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/pages/offline/offline_queue_page.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/checkout_page.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/transaction_success_page.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/presentation/providers/pos_catalog_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';
import 'package:pos_mobile/presentation/widgets/offline_banner.dart';
import 'package:pos_mobile/presentation/widgets/offline_hold.dart';

// Alur yang dijalani kasir saat jaringan putus, dari tombol bayar sampai nota:
// layar harus jujur soal apa yang sudah dan belum sampai ke server.

final Map<String, dynamic> _answer = Map<String, dynamic>.from(
    (jsonDecode(File('test/fixtures/pos_catalog.json').readAsStringSync()) as Map)['data'] as Map);

PosCatalogFetch _fetch({bool offlineEnabled = true}) {
  final data = jsonDecode(jsonEncode(_answer)) as Map<String, dynamic>;
  data['offline_sales_enabled'] = offlineEnabled;
  data['cashier'] = {'id': 5, 'name': 'Alam Kasir'};
  data['shift'] = {'id': 8, 'shift_name': 'Shift 1', 'shift_date': '2026-10-10', 'last_queue_no': 41};
  return PosCatalogFetch.fromJson(data, fetchedAt: DateTime.now());
}

const _putus = TransactionSubmitException('Tidak ada jawaban dari server', rejected: false, unreachable: true);

class _CatalogRepo implements PosCatalogRepository {
  final bool offlineEnabled;
  bool online = true;
  _CatalogRepo({this.offlineEnabled = true});

  @override
  Future<PosCatalogFetch> fetch({String? version}) async {
    if (!online) throw 'Tidak bisa menghubungi server. Periksa koneksi.';
    return _fetch(offlineEnabled: offlineEnabled);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _CatalogStore implements CatalogStore {
  final Map<int, StoredCatalog> rows = {};
  @override
  Future<StoredCatalog?> read(int branchId) async => rows[branchId];
  @override
  Future<void> write(int branchId, StoredCatalog catalog) async => rows[branchId] = catalog;
  @override
  Future<void> delete(int branchId) async => rows.remove(branchId);
}

/// Server penjualan palsu: bisa diputus, mencatat apa yang sampai.
class _Sales implements ProductTransactionRepository {
  bool online = true;
  int onlineAttempts = 0;
  final List<String> received = [];

  @override
  Future<ProductTransactionResponse> createTransaction(ProductTransactionRequest request) async {
    onlineAttempts++;
    if (!online) throw _putus;
    return ProductTransactionResponse(invoiceNumber: 'INV-20261010-0042', saleId: 1, success: true, queueNo: 42);
  }

  @override
  Future<bool> ping() async => online;

  @override
  Future<String> sendOffline(Map<String, dynamic> payload) async {
    if (!online) throw _putus;
    received.add(payload['client_ref'] as String);
    return 'INV-20261010-00${50 + received.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Antrean di memori dengan perilaku yang sama seperti versi SQLite (yang
/// diuji tersendiri di jualan_offline_test.dart).
class _MemoryOutbox implements OutboxStore {
  final List<OutboxEntry> rows = [];
  final Map<String, String> metas = {};
  int _id = 0;

  int _bump(String key) {
    final next = (int.tryParse(metas[key] ?? '') ?? 0) + 1;
    metas[key] = '$next';
    return next;
  }

  OutboxEntry _copy(OutboxEntry e, {String? status, int? attempts, String? lastError, String? invoiceNo, DateTime? sentAt}) =>
      OutboxEntry(
        id: e.id,
        branchId: e.branchId,
        idempotencyKey: e.idempotencyKey,
        clientRef: e.clientRef,
        occurredAt: e.occurredAt,
        total: e.total,
        payload: e.payload,
        receipt: e.receipt,
        status: status ?? e.status,
        attempts: attempts ?? e.attempts,
        lastError: lastError ?? e.lastError,
        invoiceNo: invoiceNo ?? e.invoiceNo,
        sentAt: sentAt ?? e.sentAt,
      );

  void _replace(int id, OutboxEntry Function(OutboxEntry) f) {
    final i = rows.indexWhere((e) => e.id == id);
    rows[i] = f(rows[i]);
  }

  @override
  Future<OutboxEntry> record({
    required int branchId,
    required int shiftId,
    required String idempotencyKey,
    required DateTime occurredAt,
    required int total,
    required OutboxDraft Function(OfflineNumbers numbers) build,
  }) async {
    final existing = rows.where((e) => e.idempotencyKey == idempotencyKey);
    if (existing.isNotEmpty) return existing.first;
    final d = '${occurredAt.year}${occurredAt.month.toString().padLeft(2, '0')}${occurredAt.day.toString().padLeft(2, '0')}';
    final draft = build(OfflineNumbers(noteSeq: _bump('note:$branchId:$d'), queueNo: _bump('queue:$shiftId')));
    final entry = OutboxEntry(
      id: ++_id,
      branchId: branchId,
      idempotencyKey: idempotencyKey,
      clientRef: draft.clientRef,
      occurredAt: occurredAt,
      total: total,
      payload: draft.payload,
      receipt: draft.receipt,
      status: OutboxStatus.pending,
    );
    rows.add(entry);
    return entry;
  }

  @override
  Future<List<OutboxEntry>> pending(int branchId) async =>
      rows.where((e) => e.branchId == branchId && e.isPending).toList();

  @override
  Future<List<OutboxEntry>> list(int branchId, {int limit = 200}) async =>
      rows.where((e) => e.branchId == branchId).toList().reversed.toList();

  @override
  Future<OutboxEntry?> byClientRef(int branchId, String clientRef) async =>
      rows.where((e) => e.clientRef == clientRef).firstOrNull;

  @override
  Future<({int pending, int failed})> counts(int branchId) async => (
        pending: rows.where((e) => e.branchId == branchId && e.isPending).length,
        failed: rows.where((e) => e.branchId == branchId && e.isFailed).length,
      );

  @override
  Future<int> pendingAnywhere() async => rows.where((e) => e.isPending).length;

  @override
  Future<void> markSent(int id, {required String invoiceNo, required DateTime at}) async =>
      _replace(id, (e) => _copy(e, status: OutboxStatus.sent, invoiceNo: invoiceNo, sentAt: at));

  @override
  Future<void> markFailed(int id, String error) async =>
      _replace(id, (e) => _copy(e, status: OutboxStatus.failed, attempts: e.attempts + 1, lastError: error));

  @override
  Future<void> noteAttempt(int id, String error) async =>
      _replace(id, (e) => _copy(e, attempts: e.attempts + 1, lastError: error));

  @override
  Future<void> retry(int id) async => _replace(id, (e) => _copy(e, status: OutboxStatus.pending));

  @override
  Future<int> purgeSent(DateTime before) async => 0;

  @override
  Future<String?> meta(String key) async => metas[key];

  @override
  Future<void> setMeta(String key, String value) async => metas[key] = value;

  @override
  Future<String> deviceId() async => 'tablet-uji';

  @override
  Future<void> observeQueueNo(int shiftId, int queueNo) async {
    final current = int.tryParse(metas['queue:$shiftId'] ?? '') ?? 0;
    if (queueNo > current) metas['queue:$shiftId'] = '$queueNo';
  }

  @override
  Future<int> lastQueueNo(int shiftId) async => int.tryParse(metas['queue:$shiftId'] ?? '') ?? 0;
}

class _Kasir {
  final ProviderContainer container;
  final _Sales sales;
  final _CatalogRepo catalogRepo;
  final _MemoryOutbox outbox;
  _Kasir(this.container, this.sales, this.catalogRepo, this.outbox);

  OfflineNotifier get offline => container.read(offlineProvider.notifier);
  OfflineState get state => container.read(offlineProvider);

  /// Listrik mati: server tak terjangkau dari mana pun, dan aplikasi sudah tahu.
  Future<void> putus(WidgetTester tester) async {
    await tester.pump(); // biarkan jawaban katalog terakhir selesai diolah
    sales.online = false;
    catalogRepo.online = false;
    offline.markUnreachable();
  }

  void tersambung() {
    sales.online = true;
    catalogRepo.online = true;
  }
}

/// Kasir yang sudah login, katalog termuat, dan satu Es Teh Jumbo di keranjang.
Future<_Kasir> _kasir({bool offlineEnabled = true}) async {
  final sales = _Sales();
  final catalogRepo = _CatalogRepo(offlineEnabled: offlineEnabled);
  final outbox = _MemoryOutbox();
  final container = ProviderContainer(overrides: [
    posCatalogRepositoryProvider.overrideWithValue(catalogRepo),
    catalogStoreProvider.overrideWithValue(_CatalogStore()),
    activeBranchIdProvider.overrideWithValue(7),
    productTransactionRepositoryProvider.overrideWithValue(sales),
    outboxStoreProvider.overrideWithValue(outbox),
  ]);
  container.listen(productTransactionProvider, (previous, next) {});
  container.listen(posCatalogProvider, (previous, next) {});
  container.listen(offlineProvider, (previous, next) {});
  await container.read(posCatalogProvider.notifier).refresh();
  final teh = container.read(posCatalogProvider).catalog!.products.firstWhere((p) => p.name == 'Es Teh');
  container.read(productTransactionProvider.notifier).addToCart(teh, variant: teh.variants.single);
  return _Kasir(container, sales, catalogRepo, outbox);
}

Future<void> _pump(WidgetTester tester, ProviderContainer container, Widget page) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(home: page)));
  await tester.pumpAndSettle();
}

/// Tutup layar dan lepas provider di dalam tes: katalog dan mode offline
/// sama-sama punya pewaktu berkala yang harus sudah berhenti.
Future<void> _close(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
}

Future<void> _bayar(WidgetTester tester) async {
  final tombol = find.textContaining('Konfirmasi & Bayar');
  await tester.ensureVisible(tombol);
  await tester.tap(tombol);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
    // Halaman sukses membaca setelan printer; di sini belum ada printer.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  testWidgets('jaringan putus saat bayar tunai: tersimpan di HP, nota lokal tampil', (tester) async {
    final k = await _kasir();
    await _pump(tester, k.container, const CheckoutPage());
    k.sales.online = false;

    await _bayar(tester);

    expect(k.sales.onlineAttempts, 1, reason: 'dicoba online dulu');
    expect(find.byType(TransactionSuccessPage), findsOneWidget);
    expect(find.text('Tersimpan di HP'), findsOneWidget);
    expect(find.text('NOMOR NOTA'), findsOneWidget);
    final nota = k.outbox.rows.single;
    expect(find.text(nota.clientRef), findsOneWidget);
    expect(nota.clientRef, startsWith('OFF-'));
    expect(find.textContaining('Antrean 42'), findsOneWidget, reason: 'melanjutkan nomor 41 dari server');
    expect(find.textContaining('Kembalian'), findsOneWidget);
    expect(k.state.pending, 1);
    expect(k.container.read(productTransactionProvider).items, isEmpty);
    await _close(tester, k.container);
  });

  testWidgets('sudah mode offline: tunai langsung disimpan tanpa menunggu server', (tester) async {
    final k = await _kasir();
    await k.putus(tester);
    await _pump(tester, k.container, const CheckoutPage());

    expect(find.textContaining('Mode offline'), findsOneWidget);
    await _bayar(tester);

    expect(k.sales.onlineAttempts, 0);
    expect(find.text('Tersimpan di HP'), findsOneWidget);
    expect(k.outbox.rows, hasLength(1));
    await _close(tester, k.container);
  });

  testWidgets('cabang tanpa jualan offline: gagal seperti biasa, keranjang utuh', (tester) async {
    final k = await _kasir(offlineEnabled: false);
    await _pump(tester, k.container, const CheckoutPage());
    k.sales.online = false;

    await _bayar(tester);

    expect(find.byType(TransactionSuccessPage), findsNothing);
    expect(find.textContaining('belum diaktifkan'), findsOneWidget);
    expect(k.outbox.rows, isEmpty);
    expect(k.container.read(productTransactionProvider).items, hasLength(1));
    await _close(tester, k.container);
  });

  testWidgets('saat offline QRIS tidak bisa dipilih', (tester) async {
    final k = await _kasir();
    await k.putus(tester);
    await _pump(tester, k.container, const CheckoutPage());

    await tester.ensureVisible(find.text('QRIS'));
    await tester.tap(find.text('QRIS'));
    await tester.pump();

    expect(find.textContaining('QRIS belum bisa dipakai'), findsOneWidget);
    expect(find.textContaining('Konfirmasi & Bayar'), findsOneWidget, reason: 'metode tetap tunai');
    await tester.pumpAndSettle(const Duration(seconds: 5)); // biarkan snackbar selesai
    await _close(tester, k.container);
  });

  testWidgets('online seperti biasa: tidak ada yang masuk antrean', (tester) async {
    final k = await _kasir();
    await _pump(tester, k.container, const CheckoutPage());

    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.textContaining('Mode offline'), findsNothing);
    await _bayar(tester);

    expect(find.text('Transaksi Berhasil!'), findsOneWidget);
    expect(find.text('INV-20261010-0042'), findsOneWidget);
    expect(k.outbox.rows, isEmpty);
    expect(await k.outbox.lastQueueNo(8), 42, reason: 'nomor antrean dari server diingat');
    await _close(tester, k.container);
  });

  testWidgets('halaman Penjualan Offline: menunggu, lalu terkirim setelah jaringan kembali', (tester) async {
    final k = await _kasir();
    await k.putus(tester);
    await k.offline.record(
      cart: k.container.read(productTransactionProvider.notifier),
      catalog: k.container.read(posCatalogProvider).catalog,
      paid: 10000,
    );
    await _pump(tester, k.container, const OfflineQueuePage());

    expect(find.text('Menunggu'), findsOneWidget);
    expect(find.textContaining('menunggu jaringan'), findsOneWidget);
    expect(find.text('Kirim sekarang'), findsOneWidget);

    k.tersambung();
    await tester.tap(find.text('Kirim sekarang'));
    await tester.pumpAndSettle();

    expect(k.sales.received, [k.outbox.rows.single.clientRef]);
    expect(find.text('Terkirim'), findsOneWidget);
    expect(find.textContaining('Invoice INV-'), findsOneWidget);
    expect(find.textContaining('sudah terkirim'), findsOneWidget);
    await _close(tester, k.container);
  });

  testWidgets('tiap penjualan offline punya tombol nota, dan notanya utuh di HP', (tester) async {
    final k = await _kasir();
    await k.putus(tester);
    await k.offline.record(
      cart: k.container.read(productTransactionProvider.notifier),
      catalog: k.container.read(posCatalogProvider).catalog,
      paid: 10000,
    );
    await _pump(tester, k.container, const OfflineQueuePage());

    expect(find.text('Nota'), findsOneWidget);
    final nota = Receipt.fromJson(jsonDecode(k.outbox.rows.single.receipt) as Map<String, dynamic>);
    expect(nota.items.single.displayName, 'Es Teh - Jumbo');
    expect(nota.store.name, 'Cabang Uji');
    expect(nota.queueNo, 42);
    await _close(tester, k.container);
  });

  testWidgets('penahan: ada yang belum terkirim → ditahan; kosong → boleh', (tester) async {
    final k = await _kasir();
    late BuildContext ctx;
    late WidgetRef widgetRef;
    await _pump(
      tester,
      k.container,
      Consumer(builder: (context, ref, _) {
        ctx = context;
        widgetRef = ref;
        return const Scaffold(body: SizedBox());
      }),
    );

    expect(await ensureNothingUnsent(ctx, widgetRef, action: 'Tutup shift'), isTrue);

    await k.putus(tester);
    await k.offline.record(
      cart: k.container.read(productTransactionProvider.notifier),
      catalog: k.container.read(posCatalogProvider).catalog,
      paid: 10000,
    );
    final held = ensureNothingUnsent(ctx, widgetRef, action: 'Tutup shift');
    await tester.pumpAndSettle();

    expect(find.text('Masih Ada yang Belum Terkirim'), findsOneWidget);
    expect(find.textContaining('Tutup shift ditahan'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(await held, isFalse);
    await _close(tester, k.container);
  });
}
