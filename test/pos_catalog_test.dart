import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_mobile/data/local/catalog_store.dart';
import 'package:pos_mobile/data/local/kasir_local_db.dart';
import 'package:pos_mobile/data/models/plastic_model.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/sedotan_model.dart';
import 'package:pos_mobile/data/repositories/pos_catalog_repository.dart';
import 'package:pos_mobile/presentation/providers/pos_catalog_provider.dart';
import 'package:pos_mobile/presentation/providers/product_pagination_provider.dart';

// Layar POS kini selalu membaca menu dari potret di HP. Yang dijaga di sini:
// potret tidak pernah diganti oleh sesuatu yang belum terbaca utuh, tidak
// pernah membuat aplikasi macet, dan katalog cabang lain tidak pernah terpakai.

/// Jawaban `GET /pos/catalog` asli dari server (lihat test/fixtures).
final Map<String, dynamic> _answer = Map<String, dynamic>.from(
    (jsonDecode(File('test/fixtures/pos_catalog.json').readAsStringSync()) as Map)['data'] as Map);

final _fetchedAt = DateTime(2026, 10, 10, 13, 5);

PosCatalogFetch _fetch({String? version, String? firstProductName}) {
  final data = jsonDecode(jsonEncode(_answer)) as Map<String, dynamic>;
  if (version != null) data['version'] = version;
  if (firstProductName != null) (data['products'] as List).first['name'] = firstProductName;
  return PosCatalogFetch.fromJson(data, fetchedAt: _fetchedAt);
}

PosCatalogFetch _unchanged(String version) =>
    PosCatalogFetch.fromJson({'version': version, 'unchanged': true}, fetchedAt: _fetchedAt);

/// Repo palsu: mencatat versi yang ditanyakan dan menjawab sesuai antrean.
class _FakeRepo implements PosCatalogRepository {
  final List<String?> asked = [];
  final List<Object> answers = [];
  Completer<void>? gate;

  @override
  Future<PosCatalogFetch> fetch({String? version}) async {
    asked.add(version);
    if (gate != null) await gate!.future;
    final next = answers.removeAt(0);
    if (next is PosCatalogFetch) return next;
    throw next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MemoryStore implements CatalogStore {
  final Map<int, StoredCatalog> rows = {};
  int writes = 0;
  bool broken = false;

  @override
  Future<StoredCatalog?> read(int branchId) async {
    if (broken) throw StateError('DB tidak bisa dibuka');
    return rows[branchId];
  }

  @override
  Future<void> write(int branchId, StoredCatalog catalog) async {
    if (broken) throw StateError('DB tidak bisa dibuka');
    writes++;
    rows[branchId] = catalog;
  }

  @override
  Future<void> delete(int branchId) async {
    if (broken) throw StateError('DB tidak bisa dibuka');
    rows.remove(branchId);
  }
}

PosCatalogNotifier _notifier(_FakeRepo repo, _MemoryStore store, {int? branchId = 7}) {
  final n = PosCatalogNotifier(
    repo: repo,
    store: store,
    branchId: branchId,
    checkInterval: const Duration(days: 1), // pengecekan berkala tidak diuji di sini
  );
  addTearDown(n.dispose);
  return n;
}

void main() {
  group('membaca jawaban server', () {
    final fetch = _fetch();
    final c = fetch.catalog!;

    test('versi, toko, sakelar offline, dan shift', () {
      expect(fetch.unchanged, isFalse);
      expect(c.version, 'a9ed08c06022564e');
      expect(c.store.name, 'Cabang Uji');
      expect(c.store.footerNote, 'Terima kasih');
      expect(c.offlineSalesEnabled, isTrue);
      expect(fetch.shift!.id, 1);
      expect(fetch.shift!.lastQueueNo, 0);
      expect(fetch.serverTime, isNotNull);
    });

    test('produk membawa varian, harga, slot topping, dan tanda siap', () {
      final teh = c.products.firstWhere((p) => p.name == 'Es Teh');
      expect(teh.hasVariants, isTrue);
      expect(teh.ready, isTrue);
      expect(teh.categoryFreeable, isTrue);
      final jumbo = teh.variants.single;
      expect(jumbo.name, 'Jumbo');
      expect(jumbo.sellingPriceNum, 7000);
      expect(jumbo.freeToppingSlots, 1);
      expect(jumbo.ready, isTrue);
      expect(jumbo.effectivePrepFor(teh.prepMinutes), 2);
      expect(jumbo.productId, teh.id, reason: 'varian di daftar produk dikirim tanpa product_id');

      final kopi = c.products.firstWhere((p) => p.name == 'Kopi Susu');
      expect(kopi.variants, isEmpty);
      expect(kopi.ready, isFalse, reason: 'produk habis harus tetap tampil sebagai habis');
    });

    test('yang nonaktif tidak pernah sampai ke kasir', () {
      expect(c.toppings.map((t) => t.name), ['Jelly', 'Oreo']);
      expect(c.plastics.map((p) => p.name), ['Kantong', 'Cup 16 oz']);
    });

    test('wadah dan sedotan otomatis tetap terbaca', () {
      expect(c.plastics.where((p) => p.isPickedManually).map((p) => p.name), ['Kantong']);
      expect(c.sedotans.firstWhere((s) => s.name == 'Sedotan besar').autoFor,
          SedotanAutoFor.withTopping);
    });

    // Server mengirim promo untuk semua hari: potret hari Senin bisa masih
    // dipakai hari Selasa.
    test('promo disaring per hari di HP', () {
      expect(c.promos, hasLength(2));
      expect(c.promosOn(1).map((p) => p.name), ['Beli 2 Gratis 1']); // Senin
      expect(c.promosOn(5).map((p) => p.name), ['Beli 2 Gratis 1', 'Jumat Berkah']); // Jumat
      expect(identical(c.promosOn(5), c.promosOn(5)), isTrue,
          reason: 'daftar yang sama persis, supaya layar tidak digambar ulang tiap menit');
    });

    test('jawaban unchanged tidak membawa katalog', () {
      final same = _unchanged('a9ed08c06022564e');
      expect(same.unchanged, isTrue);
      expect(same.catalog, isNull);
      expect(same.stored, isNull);
    });

    test('yang disimpan bisa dibaca kembali menjadi katalog yang sama', () {
      final back = PosCatalog.fromStored(fetch.stored!);
      expect(back.version, c.version);
      expect(back.fetchedAt, _fetchedAt);
      expect(back.products.map((p) => p.name), c.products.map((p) => p.name));
      expect(back.toppings.length, c.toppings.length);
      expect(jsonDecode(fetch.stored!.payload), isNot(contains('shift')),
          reason: 'shift dan jam server berubah sendiri, bukan isi katalog');
    });

    test('isi yang tidak utuh ditolak, bukan dibaca sebagai katalog kosong', () {
      final broken = jsonDecode(jsonEncode(_answer)) as Map<String, dynamic>..remove('toppings');
      expect(() => PosCatalogFetch.fromJson(broken, fetchedAt: _fetchedAt), throwsA(anything));
    });
  });

  group('penyimpanan di HP (SQLite)', () {
    late Database db;
    late SqfliteCatalogStore store;

    setUpAll(sqfliteFfiInit);
    setUp(() async {
      db = await openKasirLocalDb(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      store = SqfliteCatalogStore(Future.value(db));
    });
    tearDown(() => db.close());

    test('kosong sebelum pernah menyimpan', () async {
      expect(await store.read(7), isNull);
    });

    test('simpan lalu baca', () async {
      await store.write(7, _fetch().stored!);
      final got = (await store.read(7))!;
      expect(got.schema, posCatalogSchema);
      expect(got.version, 'a9ed08c06022564e');
      expect(got.fetchedAt, _fetchedAt);
      expect(PosCatalog.fromStored(got).products, hasLength(2));
    });

    test('potret baru menggantikan yang lama, tetap satu baris', () async {
      await store.write(7, _fetch(version: 'v1').stored!);
      await store.write(7, _fetch(version: 'v2').stored!);
      expect((await store.read(7))!.version, 'v2');
      expect(await db.query('catalog'), hasLength(1));
    });

    test('tiap cabang punya potretnya sendiri', () async {
      await store.write(7, _fetch(version: 'cabang-7').stored!);
      await store.write(8, _fetch(version: 'cabang-8').stored!);
      expect((await store.read(7))!.version, 'cabang-7');
      expect((await store.read(8))!.version, 'cabang-8');
      await store.delete(7);
      expect(await store.read(7), isNull);
      expect((await store.read(8))!.version, 'cabang-8');
    });
  });

  group('katalog di layar', () {
    test('HP baru: unduh, tampilkan, simpan', () async {
      final repo = _FakeRepo()..answers.add(_fetch());
      final store = _MemoryStore();
      final n = _notifier(repo, store);

      await n.start();

      expect(repo.asked, [null], reason: 'belum punya versi untuk ditanyakan');
      expect(n.state.catalog!.products, hasLength(2));
      expect(n.state.error, isNull);
      expect(store.rows[7]!.version, 'a9ed08c06022564e');
    });

    test('sudah punya potret: tampil sebelum server menjawab', () async {
      final store = _MemoryStore()..rows[7] = _fetch(version: 'lama').stored!;
      final repo = _FakeRepo()
        ..gate = Completer<void>()
        ..answers.add(_unchanged('lama'));
      final n = _notifier(repo, store);

      final started = n.start();
      await pumpEventQueue();

      expect(n.state.catalog!.version, 'lama', reason: 'potret lokal sudah tampil');
      expect(n.state.refreshing, isTrue, reason: 'server belum menjawab');
      expect(repo.asked, ['lama']);

      repo.gate!.complete();
      await started;

      expect(n.state.refreshing, isFalse);
      expect(store.writes, 0, reason: 'tidak berubah berarti tidak ada yang ditulis');
    });

    test('server punya versi baru: potret diganti', () async {
      final store = _MemoryStore()..rows[7] = _fetch(version: 'lama').stored!;
      final repo = _FakeRepo()..answers.add(_fetch(version: 'baru', firstProductName: 'Kopi Susu Aren'));
      final n = _notifier(repo, store);

      await n.start();

      expect(n.state.catalog!.version, 'baru');
      expect(n.state.catalog!.products.first.name, 'Kopi Susu Aren');
      expect(store.rows[7]!.version, 'baru');
    });

    test('server tak terjangkau: potret lama tetap dipakai, galatnya terlihat', () async {
      final store = _MemoryStore()..rows[7] = _fetch(version: 'lama').stored!;
      final repo = _FakeRepo()..answers.add('Tidak bisa menghubungi server. Periksa koneksi.');
      final n = _notifier(repo, store);

      await n.start();

      expect(n.state.catalog!.version, 'lama');
      expect(n.state.error, contains('server'));
      expect(n.state.pick((c) => c.toppings).hasValue, isTrue,
          reason: 'layar tetap punya isi walau pembaruan gagal');
      expect(store.rows[7]!.version, 'lama');
    });

    test('HP baru dan server tak terjangkau: galat, bukan memuat selamanya', () async {
      final repo = _FakeRepo()..answers.add('Tidak bisa menghubungi server. Periksa koneksi.');
      final n = _notifier(repo, _MemoryStore());

      await n.start();

      expect(n.state.catalog, isNull);
      expect(n.state.pick((c) => c.toppings).hasError, isTrue);
    });

    test('pembaruan berikutnya yang berhasil menghapus galat', () async {
      final repo = _FakeRepo()..answers.addAll(['putus', _fetch()]);
      final n = _notifier(repo, _MemoryStore());

      await n.start();
      expect(n.state.error, isNotNull);
      await n.refresh();

      expect(n.state.error, isNull);
      expect(n.state.catalog, isNotNull);
    });

    test('potret dari versi aplikasi lain dibuang, lalu diunduh ulang', () async {
      final old = _fetch(version: 'lama').stored!;
      final store = _MemoryStore()
        ..rows[7] = StoredCatalog(
            schema: posCatalogSchema + 1, version: old.version, fetchedAt: old.fetchedAt, payload: old.payload);
      final repo = _FakeRepo()..answers.add(_fetch(version: 'baru'));
      final n = _notifier(repo, store);

      await n.start();

      expect(repo.asked, [null], reason: 'versi potret yang dibuang tidak boleh ditanyakan');
      expect(n.state.catalog!.version, 'baru');
      expect(store.rows[7]!.schema, posCatalogSchema);
    });

    test('potret rusak dibuang dan aplikasi tetap jalan', () async {
      final store = _MemoryStore()
        ..rows[7] = StoredCatalog(
            schema: posCatalogSchema, version: 'rusak', fetchedAt: _fetchedAt, payload: '{"products": "bukan daftar"');
      final repo = _FakeRepo()..answers.add(_fetch(version: 'baru'));
      final n = _notifier(repo, store);

      await n.start();

      expect(repo.asked, [null]);
      expect(n.state.catalog!.version, 'baru');
    });

    test('DB lokal tidak bisa dibuka: tetap jalan dari server', () async {
      final store = _MemoryStore()..broken = true;
      final repo = _FakeRepo()..answers.add(_fetch());
      final n = _notifier(repo, store);

      await n.start();

      expect(n.state.catalog, isNotNull);
      expect(n.state.error, isNull);
    });

    test('jawaban server yang tak terbaca tidak menimpa potret', () async {
      final store = _MemoryStore()..rows[7] = _fetch(version: 'lama').stored!;
      final repo = _FakeRepo()..answers.add(const FormatException('isi katalog tidak utuh'));
      final n = _notifier(repo, store);

      await n.start();

      expect(n.state.catalog!.version, 'lama');
      expect(store.rows[7]!.version, 'lama');
      expect(store.writes, 0);
    });

    test('katalog cabang lain tidak pernah terpakai', () async {
      final store = _MemoryStore()..rows[7] = _fetch(version: 'cabang-7').stored!;
      final repo = _FakeRepo()..answers.add(_fetch(version: 'cabang-8'));
      final n = _notifier(repo, store, branchId: 8);

      final started = n.start();
      await pumpEventQueue();
      await started;

      expect(repo.asked, [null], reason: 'cabang 8 belum punya potret; milik cabang 7 tidak dipakai');
      expect(store.rows[7]!.version, 'cabang-7');
      expect(store.rows[8]!.version, 'cabang-8');
    });

    test('sebelum apa pun terbaca: memuat, bukan kosong', () {
      final n = _notifier(_FakeRepo(), _MemoryStore());

      expect(n.state.refreshing, isTrue);
      expect(n.state.pick((c) => c.toppings).isLoading, isTrue);
    });

    test('dua permintaan pembaruan bersamaan hanya bertanya sekali', () async {
      final repo = _FakeRepo()
        ..gate = Completer<void>()
        ..answers.add(_fetch());
      final n = _notifier(repo, _MemoryStore());

      final a = n.refresh();
      final b = n.refresh();
      repo.gate!.complete();
      await Future.wait([a, b]);

      expect(repo.asked, hasLength(1));
    });
  });

  group('daftar produk POS mengikuti katalog', () {
    test('isi, tanda memuat, dan galat diteruskan apa adanya', () {
      var refreshed = 0;
      final list = ProductPaginationNotifier(() async => refreshed++);
      addTearDown(list.dispose);
      final catalog = _fetch().catalog!;

      list.applyCatalog(const PosCatalogState(refreshing: true));
      expect(list.state.loading, isTrue);
      expect(list.state.allItems, isEmpty);

      list.applyCatalog(PosCatalogState(catalog: catalog));
      expect(list.state.loading, isFalse);
      expect(list.state.allItems, hasLength(2));
      expect(list.state.categories.single.name, 'Minuman');

      // Pembaruan gagal: daftar lama bertahan, galat muncul untuk spanduk.
      list.applyCatalog(PosCatalogState(catalog: catalog, error: 'putus'));
      expect(list.state.allItems, hasLength(2));
      expect(list.state.error, 'putus');

      list.applyCatalog(PosCatalogState(catalog: catalog));
      expect(list.state.error, isNull);

      list.loadAll();
      expect(refreshed, 1, reason: 'tarik-refresh meminta katalog diperbarui');
    });

    test('keadaan yang sama tidak menggambar ulang layar', () {
      final list = ProductPaginationNotifier(() async {});
      addTearDown(list.dispose);
      final catalog = _fetch().catalog!;
      var notified = 0;
      list.addListener((_) => notified++, fireImmediately: false);

      list.applyCatalog(PosCatalogState(catalog: catalog));
      list.applyCatalog(PosCatalogState(catalog: catalog));
      list.applyCatalog(PosCatalogState(catalog: catalog));

      expect(notified, 1);
    });
  });
}
