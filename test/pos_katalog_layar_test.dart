import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/local/catalog_store.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/repositories/pos_catalog_repository.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/checkout_page.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/product_transaction_page.dart';
import 'package:pos_mobile/presentation/providers/pos_catalog_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

// Layar POS dan checkout dirangkai ke katalog lewat beberapa provider. Tes ini
// menjalankan layarnya sungguhan, supaya salah sambung (daftar kosong, seksi
// yang hilang, topping yang tak muncul) ketahuan di sini dan bukan di outlet.

final Map<String, dynamic> _answer = Map<String, dynamic>.from(
    (jsonDecode(File('test/fixtures/pos_catalog.json').readAsStringSync()) as Map)['data'] as Map);

PosCatalogFetch _fetch() => PosCatalogFetch.fromJson(
    jsonDecode(jsonEncode(_answer)) as Map<String, dynamic>,
    fetchedAt: DateTime(2026, 10, 10, 13, 5));

class _Repo implements PosCatalogRepository {
  final Object? failure;
  _Repo({this.failure});

  @override
  Future<PosCatalogFetch> fetch({String? version}) async {
    if (failure != null) throw failure!;
    return _fetch();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Store implements CatalogStore {
  final Map<int, StoredCatalog> rows = {};
  @override
  Future<StoredCatalog?> read(int branchId) async => rows[branchId];
  @override
  Future<void> write(int branchId, StoredCatalog catalog) async => rows[branchId] = catalog;
  @override
  Future<void> delete(int branchId) async => rows.remove(branchId);
}

class _NoSales implements ProductTransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ProviderContainer _container({_Repo? repo, _Store? store}) {
  return ProviderContainer(overrides: [
    posCatalogRepositoryProvider.overrideWithValue(repo ?? _Repo()),
    catalogStoreProvider.overrideWithValue(store ?? _Store()),
    activeBranchIdProvider.overrideWithValue(7),
    productTransactionRepositoryProvider.overrideWithValue(_NoSales()),
  ]);
}

/// Tutup layar dan lepas katalognya di dalam tes. Katalog mengecek versi ke
/// server tiap menit selama hidup; pewaktu itu harus sudah berhenti sebelum tes
/// dianggap selesai.
Future<void> _close(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
}

Future<void> _pump(WidgetTester tester, ProviderContainer container, Widget page) async {
  // Tablet kasir: cukup lebar supaya grid produk dan lembar pilihan muat.
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: page),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  testWidgets('daftar produk POS berisi menu dari katalog, bisa dicari', (tester) async {
    final container = _container();
    await _pump(tester, container, const ProductTransactionPage());

    expect(find.text('Es Teh'), findsOneWidget);
    expect(find.text('Kopi Susu'), findsOneWidget);
    expect(find.text('Minuman'), findsOneWidget, reason: 'tab kategori dari katalog');

    await tester.enterText(find.byType(TextField), 'kopi');
    await tester.pump(const Duration(milliseconds: 300)); // jeda ketik pencarian
    await tester.pumpAndSettle();

    expect(find.text('Kopi Susu'), findsOneWidget);
    expect(find.text('Es Teh'), findsNothing);
    await _close(tester, container);
  });

  testWidgets('server tak terjangkau: menu dari potret di HP tetap tampil', (tester) async {
    final store = _Store()..rows[7] = _fetch().stored!;
    final container =
        _container(repo: _Repo(failure: 'Tidak bisa menghubungi server. Periksa koneksi.'), store: store);
    await _pump(tester, container, const ProductTransactionPage());

    expect(find.text('Es Teh'), findsOneWidget);
    expect(find.text('Kopi Susu'), findsOneWidget);
    await _close(tester, container);
  });

  testWidgets('HP baru dan server tak terjangkau: pesan gagal, bukan memuat selamanya', (tester) async {
    final container = _container(repo: _Repo(failure: 'Tidak bisa menghubungi server. Periksa koneksi.'));
    await _pump(tester, container, const ProductTransactionPage());

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Gagal memuat produk'), findsOneWidget);
    await _close(tester, container);
  });

  testWidgets('pilih produk: ukuran lalu topping, semuanya dari katalog', (tester) async {
    final container = _container();
    await _pump(tester, container, const ProductTransactionPage());

    await tester.tap(find.text('Es Teh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jumbo'), findsWidgets, reason: 'lembar pilih ukuran');

    await tester.tap(find.textContaining('Jumbo').first);
    await tester.pumpAndSettle();

    // Lembar topping: hanya topping aktif dari katalog.
    expect(find.textContaining('Oreo'), findsWidgets);
    expect(find.textContaining('Jelly'), findsWidgets);
    expect(find.textContaining('Boba'), findsNothing, reason: 'topping nonaktif tidak boleh muncul');
    await _close(tester, container);
  });

  testWidgets('checkout: kantong, sedotan, dan promo dari katalog', (tester) async {
    final container = _container();
    // Keranjang hidup selama ada yang mendengarkan, seperti saat halaman POS terbuka.
    container.listen(productTransactionProvider, (previous, next) {});
    container.listen(posCatalogProvider, (previous, next) {});
    await container.read(posCatalogProvider.notifier).refresh();
    final catalog = container.read(posCatalogProvider).catalog!;
    final teh = catalog.products.firstWhere((p) => p.name == 'Es Teh');
    container.read(productTransactionProvider.notifier)
      ..addToCart(teh, variant: teh.variants.single)
      ..addToCart(teh, variant: teh.variants.single);

    await _pump(tester, container, const CheckoutPage());

    expect(find.text('Kantong Bawa Pulang'), findsOneWidget);
    expect(find.text('Kantong'), findsOneWidget);
    expect(find.text('Cup 16 oz'), findsNothing, reason: 'wadah dipotong server, bukan dipilih kasir');
    expect(find.text('Kantong lama'), findsNothing, reason: 'kemasan nonaktif');

    expect(find.text('Sedotan'), findsOneWidget);
    expect(find.text('Sedotan kecil'), findsOneWidget);
    expect(find.text('Sedotan besar'), findsOneWidget);

    // Promo "Beli 2 Gratis 1" berlaku setiap hari di contoh katalog.
    expect(find.textContaining('Beli 2 Gratis 1'), findsWidgets);

    // Sedotan otomatis: dua gelas tanpa topping → sedotan kecil terisi 2.
    final cart = container.read(productTransactionProvider);
    final kecil = cart.sedotans.where((s) => s.sedotan.name == 'Sedotan kecil');
    expect(kecil.single.qty, 2);
    await _close(tester, container);
  });
}
