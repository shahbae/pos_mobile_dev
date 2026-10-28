import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/local/catalog_store.dart';
import 'package:pos_mobile/data/models/allowance_model.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/repositories/allowance_repository.dart';
import 'package:pos_mobile/data/repositories/pos_catalog_repository.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/checkout_page.dart';
import 'package:pos_mobile/presentation/providers/allowance_provider.dart';
import 'package:pos_mobile/presentation/providers/pos_catalog_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

// Layar checkout Tahap 3: promo persen terpasang sendiri, diskon manual lewat
// lembarnya, dan pesanan jatah sebagai metode bayar.

final Map<String, dynamic> _answer = Map<String, dynamic>.from(
    (jsonDecode(File('test/fixtures/pos_catalog.json').readAsStringSync()) as Map)['data'] as Map);

const _branch = 7;
const _allDays = [
  {'day_of_week': 0}, {'day_of_week': 1}, {'day_of_week': 2}, {'day_of_week': 3},
  {'day_of_week': 4}, {'day_of_week': 5}, {'day_of_week': 6},
];

/// Katalog dengan atau tanpa promo persen 15% sepanjang hari.
PosCatalogFetch _fetch({required bool percentPromo}) {
  final data = jsonDecode(jsonEncode(_answer)) as Map<String, dynamic>;
  data['promo_rules'] = [
    if (percentPromo)
      {
        'id': 10, 'name': 'Diskon 15%', 'kind': 'percent', 'percent': 15, 'scope': 'all', 'targets': [],
        'include_toppings': true, 'channel_pos': true, 'is_active': true, 'days': _allDays,
        'branches': [{'branch_id': _branch}],
      },
  ];
  data['discount_reasons'] = [
    {'id': 3, 'name': 'Komplain rasa', 'sort': 1, 'is_active': true},
  ];
  data['discount_limit_pct'] = 10;
  return PosCatalogFetch.fromJson(data, fetchedAt: DateTime(2026, 11, 3, 14));
}

class _Repo implements PosCatalogRepository {
  final bool percentPromo;
  _Repo(this.percentPromo);
  @override
  Future<PosCatalogFetch> fetch({String? version}) async => _fetch(percentPromo: percentPromo);
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

class _Allowance implements AllowanceRepository {
  @override
  Future<List<AllowanceRecipient>> recipients() async => const [
        AllowanceRecipient(userId: 6, name: 'Aenah', balance: 20000, locationName: 'Karangampel', atThisBranch: true),
        AllowanceRecipient(userId: 7, name: 'Udin', balance: 20000, locationName: 'Gudang Pusat'),
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<ProviderContainer> _open(WidgetTester tester, {required bool percentPromo}) async {
  final container = ProviderContainer(overrides: [
    posCatalogRepositoryProvider.overrideWithValue(_Repo(percentPromo)),
    catalogStoreProvider.overrideWithValue(_Store()),
    activeBranchIdProvider.overrideWithValue(_branch),
    productTransactionRepositoryProvider.overrideWithValue(_NoSales()),
    allowanceRepositoryProvider.overrideWithValue(_Allowance()),
  ]);
  container.listen(productTransactionProvider, (previous, next) {});
  container.listen(posCatalogProvider, (previous, next) {});
  await container.read(posCatalogProvider.notifier).refresh();
  final kopi = container.read(posCatalogProvider).catalog!.products.firstWhere((p) => p.name == 'Kopi Susu');
  container.read(productTransactionProvider.notifier)
    ..addToCart(kopi)
    ..addToCart(kopi); // 2 × 8.000 = 16.000

  tester.view.physicalSize = const Size(412, 3600); // lebar HP kasir
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: CheckoutPage()),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _close(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  testWidgets('promo persen terpasang sendiri; diskon manual tidak bisa ikut', (tester) async {
    final c = await _open(tester, percentPromo: true);
    expect(find.text('Promo Diskon 15%'), findsOneWidget);
    expect(find.textContaining('2.400'), findsOneWidget); // 15% × 16.000
    expect(find.textContaining('Konfirmasi & Bayar Rp'), findsOneWidget);
    expect(find.textContaining('13.600'), findsWidgets);
    expect(find.text('Diskon manual tidak bisa digabung dengan promo yang sedang terpasang.'), findsOneWidget);
    await _close(tester, c);
  });

  testWidgets('diskon manual: pilih persen dan alasan, totalnya ikut turun', (tester) async {
    final c = await _open(tester, percentPromo: false);
    await tester.tap(find.text('Beri diskon (maks 10%)'));
    await tester.pumpAndSettle();
    expect(find.text('Diskon Manual'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('discount-value')), '15');
    await tester.pumpAndSettle();
    expect(find.text('Melebihi batas akunmu 10%'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('discount-value')), '10');
    await tester.tap(find.text('Komplain rasa'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pasang diskon'));
    await tester.pumpAndSettle();

    final cart = c.read(productTransactionProvider);
    expect([cart.manualDiscount?.kind, cart.manualDiscount?.value, cart.manualDiscount?.reasonId], ['percent', 10, 3]);
    expect(find.text('Diskon (Komplain rasa)'), findsOneWidget);
    expect(find.textContaining('14.400'), findsWidgets); // 16.000 − 1.600
    await _close(tester, c);
  });

  testWidgets('jatah: metode bayar Jatah, pilih penerima, tanpa promo', (tester) async {
    final c = await _open(tester, percentPromo: true);
    await tester.tap(find.text('Jatah'));
    await tester.pumpAndSettle();
    expect(find.text('Promo Diskon 15%'), findsNothing, reason: 'jatah tanpa promo');
    expect(find.text('Pilih siapa yang menerima'), findsOneWidget);
    expect(find.text('Pilih penerima jatah'), findsOneWidget);

    await tester.tap(find.text('Pilih siapa yang menerima'));
    await tester.pumpAndSettle();
    expect(find.text('Aenah'), findsOneWidget);
    expect(find.text('Udin'), findsNothing, reason: 'lokasi lain lewat pencarian');
    await tester.enterText(find.byType(TextField).last, 'udi');
    await tester.pumpAndSettle();
    expect(find.text('Absen di Gudang Pusat'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aenah'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Catat Jatah'), findsOneWidget);
    expect(find.textContaining('untuk Aenah'), findsOneWidget);
    expect(find.textContaining('16.000'), findsWidgets);
    await _close(tester, c);
  });
}
