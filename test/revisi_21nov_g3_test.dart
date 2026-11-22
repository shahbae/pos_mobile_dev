import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/models/leader_daily_report_model.dart';
import 'package:pos_mobile/presentation/pages/reports/leader_daily_report_page.dart';
import 'package:pos_mobile/presentation/providers/daily_report_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Revisi owner 21 Nov 2026, fase 3: modal laci berputar dihitung sekali,
/// rincian setoran di laporan leader, nominal Kirim Setoran terkunci.

Map<String, dynamic> _shift(int id, String name, int closing, int diff) => {
      'shift_id': id,
      'shift_name': name,
      'cashier_name': id == 1 ? 'Diyan' : 'Patimah',
      'status': 'closed',
      'opening_cash': 400000,
      'closing_cash': closing,
      'expected_cash': closing - diff,
      'difference': diff,
      'first_of_day': id == 1,
    };

LeaderDailyReport _report({int s2Closing = 1410000, int s2Diff = 0, int required = 1442000, int minus = 0, int plus = 0}) {
  final day = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return LeaderDailyReport.fromJson({
    'date': day,
    'from': day,
    'to': day,
    'branch_id': 7,
    'branch_name': 'KARANGAMPEL',
    'shifts': [_shift(1, 'Shift 1', 832000, 0), _shift(2, 'Shift 2', s2Closing, s2Diff)],
    'totals': {
      'opening_cash': 400000,
      'expected_cash': 1842000,
      'closing_cash': 1842000 + s2Diff,
      'difference': s2Diff,
      'total_cash': 1597000,
      'total_qris': 130000,
    },
    'deposit': {
      'all_closed': true,
      'physical_collected': 1842000 + s2Diff,
      'modal_kept': 400000,
      'plus': plus,
      'minus': minus,
      'required': required,
      'qris': 130000,
    },
    'chart': {'interval': '1hour', 'points': []},
  });
}

Future<void> _pump(WidgetTester tester, LeaderDailyReport report) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [leaderDailyReportProvider.overrideWith((ref) async => report)],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const LeaderDailyReportPage()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  group('model', () {
    test('laporan leader membaca rincian setoran; server lama kosong', () {
      final r = _report();
      expect(r.deposit.required, 1442000);
      expect(r.deposit.modalKept, 400000);
      expect(r.deposit.isEmpty, isFalse);
      final old = LeaderDailyReport.fromJson({'date': '2026-11-18', 'shifts': [], 'totals': {}});
      expect(old.deposit.isEmpty, isTrue);
    });

    test('nominal setoran: tombok yang tidak dibayar keluar dari nominal', () {
      final p = DepositPreview.fromJson({
        'operational_date': '2026-11-18',
        'shifts': [
          {'shift_id': 2, 'shift_name': 'Shift 2', 'cashier_name': 'Patimah', 'difference': -20000},
        ],
        'deposit': {'all_closed': true, 'required': 1442000, 'minus': 20000},
      });
      expect(p.nominalFor({}), 1442000);
      expect(p.nominalFor({2}), 1422000);
      expect(p.shifts.single.isShort, isTrue);
    });
  });

  group('layar laporan leader', () {
    testWidgets('Rincian Setoran: modal ditinggal, setoran wajib transfer', (tester) async {
      await _pump(tester, _report());
      await tester.scrollUntilVisible(find.text('Rincian Setoran'), 300, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      expect(find.text('Setoran Tunai Wajib Transfer'), findsOneWidget);
      expect(find.text('Rp 1.442.000'), findsOneWidget);
      expect(find.text('Tidak ada selisih kas.'), findsOneWidget);
    });

    testWidgets('kas kurang: tombok wajib, angka setoran tetap genap', (tester) async {
      await _pump(tester, _report(s2Closing: 1390000, s2Diff: -20000, minus: 20000));
      await tester.scrollUntilVisible(find.text('Rincian Setoran'), 300, scrollable: find.byType(Scrollable).first);
      await tester.scrollUntilVisible(find.textContaining('wajib ditombok'), 200, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      expect(find.text('+ Rp 20.000'), findsOneWidget);
    });
  });
}
