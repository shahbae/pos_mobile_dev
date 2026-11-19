import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/data/models/expense_model.dart';
import 'package:pos_mobile/presentation/pages/expenses/expense_form_page.dart';
import 'package:pos_mobile/presentation/providers/expense_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Revisi 19 Nov gelombang 3, app kasir (langkah 15): jenis biaya dikelompokkan
// Grup A (batas harian) / Grup B (batas bulanan), dan form menampilkan
// perkiraan status dari batas persen omzet outlet.

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    );

final _limitJson = {
  'setting': {'branch_id': 12, 'daily_pct': 9, 'monthly_pct': 0.8, 'monthly_basis': 'mtd'},
  'preview': {
    'date': '2026-11-19',
    'daily_omzet': '1000000',
    'daily_pagu': '90000',
    'today_group_a': '60000',
    'month_base': '20000000',
    'monthly_pagu': '160000',
    'month_group_b': '150000',
    'cutoff_hour': 21,
    'monthly_basis': 'mtd',
  },
  'groups': {
    'A': ['Es kristal'],
    'B': ['Listrik'],
  },
};

const _types = [
  CostType(id: 1, name: 'Es kristal', expenseGroup: 'A', sort: 1),
  CostType(id: 2, name: 'Air galon', expenseGroup: 'A', sort: 2),
  CostType(id: 7, name: 'Listrik', sort: 7),
];

Finder _page() => find.byType(Scrollable).first;

Future<void> _pick(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('cost-type-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('aturan', () {
    test('grup jenis biaya, pratinjau batas, dan perkiraan status', () {
      expect(CostType.fromJson({'id': 1, 'name': 'Es kristal', 'expense_group': 'A'}).isDailyGroup, isTrue);
      expect(CostType.fromJson({'id': 7, 'name': 'Listrik', 'expense_group': 'B'}).expenseGroup, 'B');
      // Server lama tanpa expense_group = Grup B.
      expect(CostType.fromJson({'id': 7, 'name': 'Listrik'}).expenseGroup, 'B');

      final p = ExpenseLimitPreview.fromJson(_limitJson);
      expect([p.dailyPct, p.monthlyPct, p.dailyPagu, p.todayGroupA, p.monthlyPagu, p.monthGroupB, p.cutoffHour],
          [9, 0.8, 90000, 60000, 160000, 150000, 21]);

      final a = p.project('A', 30000);
      expect([a.used, a.accum, a.pagu, a.overLimit], [60000, 90000, 90000, false]); // tepat di batas = lolos
      expect(p.project('A', 30001).overLimit, isTrue);
      final b = p.project('B', 20000);
      expect([b.used, b.accum, b.overLimit], [150000, 170000, true]);
      // Mengubah pengeluaran Grup B Rp 20.000 jadi Rp 25.000: yang lama tidak dihitung dua kali.
      final e = p.project('B', 25000, replacing: 20000);
      expect([e.used, e.accum, e.overLimit], [130000, 155000, false]);
    });

    test('pengeluaran membawa batas grup dan tanda lolos otomatis', () {
      final x = ExpenseModel.fromJson({
        'id': 95,
        'approval_status': 'approved',
        'approval_decided_by': null,
        'approval_note': 'Lolos otomatis: total Grup A Rp 131.000 ≤ batas Rp 150.000',
        'limit_group': 'A',
        'limit_accum': '131000.00',
        'limit_pagu': 150000,
      });
      expect([x.limitGroup, x.limitAccum, x.limitPagu, x.isAutoApproved], ['A', 131000, 150000, true]);
      final spv = ExpenseModel.fromJson({'id': 96, 'approval_status': 'approved', 'approval_decided_by': 3, 'approval_note': 'ok'});
      expect(spv.isAutoApproved, isFalse);
      final old = ExpenseModel.fromJson({'id': 1});
      expect([old.limitGroup, old.limitAccum, old.limitPagu, old.isAutoApproved], ['', null, null, false]);
    });
  });

  group('layar', () {
    testWidgets('jenis biaya dikelompokkan Grup A / Grup B', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const ExpenseFormPage(), [
        costTypesProvider.overrideWith((ref) async => _types),
        expenseLimitProvider.overrideWith((ref) async => ExpenseLimitPreview.fromJson(_limitJson)),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-type-field')));
      await tester.pumpAndSettle();
      expect(find.text('Grup A · batas harian'), findsOneWidget);
      expect(find.text('Grup B · batas bulanan'), findsOneWidget);
      // Judul grup tidak bisa dipilih.
      await tester.tap(find.text('Grup B · batas bulanan'));
      await tester.pumpAndSettle();
      expect(find.text('Grup B · batas bulanan'), findsOneWidget);
      await tester.tap(find.text('Listrik').last);
      await tester.pumpAndSettle();
      expect(find.text('Grup B · batas bulanan'), findsNothing);
      expect(find.text('Listrik'), findsOneWidget);
    });

    testWidgets('Grup A: perkiraan langsung disetujui lalu menunggu ACC saat nominal naik', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const ExpenseFormPage(), [
        costTypesProvider.overrideWith((ref) async => _types),
        expenseLimitProvider.overrideWith((ref) async => ExpenseLimitPreview.fromJson(_limitJson)),
      ]));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '25000');
      await _pick(tester, 'Es kristal');
      expect(find.text('Grup A · batas 9% omzet hari ini'), findsOneWidget);
      expect(find.textContaining('Hari ini Rp'), findsOneWidget);
      expect(find.textContaining('Perkiraan: langsung disetujui'), findsOneWidget);

      await tester.scrollUntilVisible(find.byType(TextFormField).first, -300, scrollable: _page());
      await tester.enterText(find.byType(TextFormField).first, '40000');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('expense-limit-projection')), 300, scrollable: _page());
      expect(find.textContaining('Perkiraan: menunggu ACC SPV'), findsOneWidget);
      expect(find.textContaining('pukul 21.00'), findsOneWidget);
    });

    testWidgets('Grup B: batas bulanan dari omzet bulan berjalan', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const ExpenseFormPage(), [
        costTypesProvider.overrideWith((ref) async => _types),
        expenseLimitProvider.overrideWith((ref) async => ExpenseLimitPreview.fromJson(_limitJson)),
      ]));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '5000');
      await _pick(tester, 'Listrik');
      expect(find.text('Grup B · batas 0,8% omzet bulan berjalan'), findsOneWidget);
      expect(find.textContaining('Bulan ini Rp'), findsOneWidget);
      expect(find.textContaining('Perkiraan: langsung disetujui'), findsOneWidget);
    });
  });
}
