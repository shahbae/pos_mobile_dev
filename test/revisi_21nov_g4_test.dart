import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/data/models/kitchen_order_model.dart';
import 'package:pos_mobile/data/repositories/kitchen_repository.dart';
import 'package:pos_mobile/presentation/providers/kitchen_provider.dart';
import 'package:pos_mobile/presentation/widgets/kitchen_queue_strip.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Revisi owner 21 Nov 2026, fase 4: pita monitoring kasir di kepala Pilih
/// Produk — nomor antrean + menit, Ditinggal, dan daftar Ditinggal.

class _Repo implements KitchenRepository {
  final calls = <String>[];

  @override
  Future<KitchenOrder> updateStatus(int orderId, String status) async {
    calls.add('$orderId:$status');
    return KitchenOrder(id: orderId, branchId: 8, status: status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Kitchen extends KitchenDisplayNotifier {
  _Kitchen(_Repo repo, List<KitchenOrder> orders, {List<KitchenOrder> skipped = const []}) : super(repo, 8) {
    state = KitchenDisplayState(orders: orders, skipped: skipped, loading: false, connected: true);
  }

  @override
  Future<void> start() async {}
}

KitchenOrder _order(int id, int queue, String status, {int minutesAgo = 4}) => KitchenOrder(
      id: id,
      branchId: 8,
      status: status,
      queueNo: queue,
      paidAt: DateTime.now().subtract(Duration(minutes: minutesAgo, seconds: 10)),
      items: const [KitchenOrderItem(id: 1, name: 'Es Teh', qty: 2)],
    );

Future<void> _pump(WidgetTester tester, _Kitchen kitchen) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [kitchenDisplayProvider.overrideWith((ref) => kitchen)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(appBar: AppBar(title: const KitchenQueueStrip(), titleSpacing: 0)),
    ),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    const codec = StandardMessageCodec();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => codec.encodeMessage(<Object?>[null]),
    );
  });

  group('status Ditinggal', () {
    test('label dan nomor pendek', () {
      expect(kitchenStatusLabel(kitchenStatusSkipped), 'Ditinggal');
      expect(_order(1, 12, kitchenStatusReady).shortNumber, '#12');
    });

    test('Ditinggal pindah ke daftar terpisah; Diserahkan dari sana menghapusnya', () async {
      final repo = _Repo();
      final k = _Kitchen(repo, [_order(1, 12, kitchenStatusReady), _order(2, 13, kitchenStatusQueued)]);
      await k.setStatus(k.state.orders.first, kitchenStatusSkipped);
      expect(k.state.orders.map((o) => o.id), [2]);
      expect(k.state.skipped.single.status, kitchenStatusSkipped);
      await k.setStatus(k.state.skipped.single, kitchenStatusServed);
      expect(k.state.skipped, isEmpty);
      expect(repo.calls, ['1:skipped', '1:served']);
    });
  });

  group('pita di kepala Pilih Produk', () {
    testWidgets('nomor antrean + menit; siap bisa Diserahkan atau Ditinggal', (tester) async {
      final repo = _Repo();
      final k = _Kitchen(repo, [_order(1, 12, kitchenStatusReady), _order(2, 13, kitchenStatusPreparing, minutesAgo: 1)]);
      await _pump(tester, k);
      expect(tester.takeException(), isNull);
      expect(find.text('#12 · 4m'), findsOneWidget);
      expect(find.text('#13 · 1m'), findsOneWidget);
      expect(find.byTooltip('Buka monitoring lebar'), findsOneWidget);

      await tester.tap(find.text('#12 · 4m'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Diserahkan'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Ditinggal'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['1:skipped']);
      expect(find.text('#12 · 4m'), findsNothing);
      expect(find.text('Ditinggal 1'), findsOneWidget);
    });

    testWidgets('belum siap: hanya Ditinggal, tanpa Diserahkan', (tester) async {
      final k = _Kitchen(_Repo(), [_order(2, 13, kitchenStatusQueued)]);
      await _pump(tester, k);
      await tester.tap(find.text('#13 · 4m'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'Ditinggal'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Diserahkan'), findsNothing);
    });

    testWidgets('daftar Ditinggal: pelanggan kembali → Diserahkan', (tester) async {
      final repo = _Repo();
      final k = _Kitchen(repo, const [], skipped: [_order(5, 20, kitchenStatusSkipped)]);
      await _pump(tester, k);
      expect(find.text('Antrean kosong'), findsOneWidget);
      await tester.tap(find.text('Ditinggal 1'));
      await tester.pumpAndSettle();
      expect(find.text('Pesanan Ditinggal'), findsOneWidget);
      expect(find.text('Antrian 20'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Diserahkan'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['5:served']);
      expect(find.text('Tidak ada pesanan yang ditinggal.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
