import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/kitchen_order_model.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/repositories/kitchen_repository.dart';
import 'package:pos_mobile/data/repositories/kpi_repository.dart';
import 'package:pos_mobile/presentation/pages/kitchen/kitchen_display_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/cash_deposit_page.dart';
import 'package:pos_mobile/presentation/providers/duty_provider.dart';
import 'package:pos_mobile/presentation/providers/kitchen_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Revisi meeting owner 5 Nov. D18: bukti setoran lebih dari satu foto.
/// D19: setoran dikirim H-1. D24: monitoring dipisah kasir dan penyaji.

// PNG 1×1 supaya Image.memory tidak galat di tes.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _DepositRepo implements KpiRepository {
  String? date;
  int? amount;
  List<Uint8List>? photos;

  @override
  Future<CashDeposit> createCashDeposit({
    required String operationalDate,
    required int amount,
    required List<Uint8List> photos,
    String note = '',
  }) async {
    date = operationalDate;
    this.amount = amount;
    this.photos = photos;
    return CashDeposit.fromJson({'id': 1, 'operational_date': operationalDate, 'amount': amount, 'status': 'pending'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeKitchenRepo implements KitchenRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeKitchen extends KitchenDisplayNotifier {
  final advanced = <int>[];
  _FakeKitchen(List<KitchenOrder> orders) : super(_FakeKitchenRepo(), 8) {
    state = KitchenDisplayState(orders: orders, loading: false, connected: true);
  }
  @override
  Future<void> start() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> advance(KitchenOrder order) async => advanced.add(order.id);
}

KitchenOrder _order(int id, String status) => KitchenOrder.fromJson({
      'id': id,
      'branch_id': 8,
      'invoice_no': 'INV-$id',
      'status': status,
      'queue_no': id,
      'items': [
        {'id': id, 'name': 'Es Teh $id', 'qty': 1},
      ],
    });

final _orders = [
  _order(1, kitchenStatusQueued),
  _order(2, kitchenStatusPreparing),
  _order(3, kitchenStatusReady),
];

Future<_FakeKitchen> _pumpKitchen(WidgetTester tester, Set<KitchenView> views, {List<KitchenOrder>? orders}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final kitchen = _FakeKitchen(orders ?? _orders);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      kitchenViewsProvider.overrideWithValue(views),
      kitchenDisplayProvider.overrideWith((ref) => kitchen),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const KitchenDisplayPage()),
  ));
  await tester.pump();
  return kitchen;
}

Future<void> _pumpForm(WidgetTester tester, _DepositRepo repo, {CashDeposit? retry}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [kpiRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: CashDepositFormPage(retry: retry, pickPhoto: (_) async => _png),
    ),
  ));
  await tester.pump();
}

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    // Layar monitoring menjaga layar tetap menyala lewat plugin.
    const codec = StandardMessageCodec();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => codec.encodeMessage(<Object?>[null]),
    );
  });

  group('D24 monitoring dipisah', () {
    test('tampilan mengikuti tugas hari ini', () {
      expect(kitchenViewsForDuties([ScheduleDuty.server]), {KitchenView.server});
      expect(kitchenViewsForDuties([ScheduleDuty.cashier]), {KitchenView.cashier});
      expect(kitchenViewsForDuties([ScheduleDuty.both]), {KitchenView.server, KitchenView.cashier});
      // Dua shift dengan tugas berbeda: keduanya terbuka.
      expect(kitchenViewsForDuties([ScheduleDuty.cashier, ScheduleDuty.server]), {KitchenView.server, KitchenView.cashier});
      // Tugas tidak terbaca: tidak dikurangi.
      expect(kitchenViewsForDuties(const []), {KitchenView.server, KitchenView.cashier});
      expect(kitchenViewsForDuties(const [null]), {KitchenView.server, KitchenView.cashier});
    });

    test('tombol hanya untuk status yang menjadi tugas tampilan itu', () {
      expect(kitchenViewCanAdvance(KitchenView.server, kitchenStatusQueued), isTrue);
      expect(kitchenViewCanAdvance(KitchenView.server, kitchenStatusPreparing), isTrue);
      expect(kitchenViewCanAdvance(KitchenView.server, kitchenStatusReady), isFalse);
      expect(kitchenViewCanAdvance(KitchenView.cashier, kitchenStatusQueued), isFalse);
      expect(kitchenViewCanAdvance(KitchenView.cashier, kitchenStatusPreparing), isFalse);
      expect(kitchenViewCanAdvance(KitchenView.cashier, kitchenStatusReady), isTrue);
    });

    test('kasir melihat semua dengan yang siap di depan; penyaji hanya yang harus dibuat', () {
      expect(kitchenOrdersForView(_orders, KitchenView.server).map((o) => o.id), [1, 2]);
      expect(kitchenOrdersForView(_orders, KitchenView.cashier).map((o) => o.id), [3, 1, 2]);
      expect(kitchenViewPending(_orders, KitchenView.server), 2);
      expect(kitchenViewPending(_orders, KitchenView.cashier), 1);
    });

    testWidgets('penyaji: dua kartu dengan tombolnya, tanpa Diserahkan dan tanpa pilihan', (tester) async {
      final kitchen = await _pumpKitchen(tester, {KitchenView.server});
      expect(tester.takeException(), isNull);
      expect(find.text('Tugas hari ini: Penyaji'), findsOneWidget);
      expect(find.byType(SegmentedButton<KitchenView>), findsNothing);
      expect(find.text('Es Teh 1'), findsOneWidget);
      expect(find.text('Es Teh 3'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Mulai Buat'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Siap'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Diserahkan'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Mulai Buat'));
      await tester.pump();
      expect(kitchen.advanced, [1]);
    });

    testWidgets('kasir: hanya Diserahkan yang bisa ditekan, kartu lain hanya dibaca', (tester) async {
      final kitchen = await _pumpKitchen(tester, {KitchenView.cashier});
      expect(tester.takeException(), isNull);
      expect(find.text('Tugas hari ini: Kasir'), findsOneWidget);
      expect(find.text('Es Teh 3'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Diserahkan'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Mulai Buat'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Siap'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Diserahkan'));
      await tester.pump();
      expect(kitchen.advanced, [3]);
    });

    testWidgets('dua tugas: pilihan dengan jumlah, bisa berpindah', (tester) async {
      await _pumpKitchen(tester, {KitchenView.server, KitchenView.cashier});
      expect(tester.takeException(), isNull);
      expect(find.text('Penyaji (2)'), findsOneWidget);
      expect(find.text('Kasir (1)'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Diserahkan'), findsNothing);
      await tester.tap(find.text('Kasir (1)'));
      await tester.pump();
      expect(find.widgetWithText(FilledButton, 'Diserahkan'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Mulai Buat'), findsNothing);
    });

    testWidgets('penyaji tanpa pekerjaan: pesan kosong, walau ada pesanan siap', (tester) async {
      await _pumpKitchen(tester, {KitchenView.server}, orders: [_order(3, kitchenStatusReady)]);
      expect(tester.takeException(), isNull);
      expect(find.text('Tidak ada pesanan yang perlu dibuat'), findsOneWidget);
      expect(find.text('Es Teh 3'), findsNothing);
    });
  });

  group('D18 dan D19 setoran', () {
    test('photo_urls dibaca; server lama cukup photo_url', () {
      final many = CashDeposit.fromJson({'id': 1, 'operational_date': '2026-11-04', 'amount': 1, 'status': 'pending', 'photo_url': 'a', 'photo_urls': ['a', 'b']});
      expect(many.photoUrls, ['a', 'b']);
      final one = CashDeposit.fromJson({'id': 1, 'operational_date': '2026-11-04', 'amount': 1, 'status': 'pending', 'photo_url': 'a'});
      expect(one.photoUrls, ['a']);
      final none = CashDeposit.fromJson({'id': 1, 'operational_date': '2026-11-04', 'amount': 1, 'status': 'pending'});
      expect(none.photoUrls, isEmpty);
    });

    testWidgets('form: tanggal otomatis kemarin, boleh banyak foto sampai 5, terkirim semua', (tester) async {
      final repo = _DepositRepo();
      await _pumpForm(tester, repo);
      expect(tester.takeException(), isNull);
      final yesterday = DateUtils.addDaysToDate(DateUtils.dateOnly(DateTime.now()), -1);
      expect(find.text(DateFormat('EEE d MMM yyyy', 'id_ID').format(yesterday)), findsOneWidget);
      expect(find.textContaining(RegExp('batas kirim', caseSensitive: false)), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(find.widgetWithText(ElevatedButton, 'Kirim setoran')).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Nominal'), '1250000');
      for (var i = 0; i < kDepositMaxPhotos; i++) {
        final add = find.textContaining('Tambah bukti');
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pump();
      }
      expect(find.byTooltip('Hapus foto'), findsNWidgets(kDepositMaxPhotos));
      expect(find.textContaining('Tambah bukti'), findsNothing);

      await tester.ensureVisible(find.byTooltip('Hapus foto').first);
      await tester.tap(find.byTooltip('Hapus foto').first);
      await tester.pump();
      expect(find.byTooltip('Hapus foto'), findsNWidgets(kDepositMaxPhotos - 1));
      expect(find.textContaining('Tambah bukti (4/5)'), findsOneWidget);

      final send = find.widgetWithText(ElevatedButton, 'Kirim setoran');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      expect(repo.date, _ymd(yesterday));
      expect(repo.amount, 1250000);
      expect(repo.photos, hasLength(4));
    });

    testWidgets('kirim ulang tanggal lama: tanggalnya tetap, ditandai lewat batas', (tester) async {
      final old = DateUtils.addDaysToDate(DateUtils.dateOnly(DateTime.now()), -5);
      await _pumpForm(tester, _DepositRepo(),
          retry: CashDeposit.fromJson({'id': 2, 'operational_date': _ymd(old), 'amount': '900000', 'status': 'rejected'}));
      expect(tester.takeException(), isNull);
      expect(find.text(DateFormat('EEE d MMM yyyy', 'id_ID').format(old)), findsOneWidget);
      expect(find.textContaining('setoran tercatat terlambat'), findsOneWidget);
      expect(find.text('900.000'), findsOneWidget);
    });

    testWidgets('kirim ulang bertanggal hari ini (data lama): pindah ke kemarin', (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      await _pumpForm(tester, _DepositRepo(),
          retry: CashDeposit.fromJson({'id': 2, 'operational_date': _ymd(today), 'amount': '900000', 'status': 'rejected'}));
      expect(tester.takeException(), isNull);
      final yesterday = DateUtils.addDaysToDate(today, -1);
      expect(find.text(DateFormat('EEE d MMM yyyy', 'id_ID').format(yesterday)), findsOneWidget);
    });
  });
}
