import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/data/models/page_result.dart';
import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/data/repositories/stock_audit_repository.dart';
import 'package:pos_mobile/presentation/pages/stock_audits/daily_audit_gate.dart';
import 'package:pos_mobile/presentation/pages/stock_audits/stock_audit_detail_page.dart';
import 'package:pos_mobile/presentation/pages/stock_audits/stock_audit_form_page.dart';
import 'package:pos_mobile/presentation/pages/stock_audits/stock_audit_list_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_audit_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Tahap 5 Opname, app kasir: jenis audit, hitungan buta, alasan barang tidak
// wajar, dan opname harian sebelum Shift 2 ditutup.

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _auditJson({String reason = '', String status = 'draft', int missing = 1}) => {
      'id': 41,
      'created_by': 1,
      'status': status,
      'notes': '',
      'audit_type': 'daily',
      'period_key': '2026-11-02',
      'counted_at': '2026-11-02T21:30:00+07:00',
      'unfair_count': 1,
      'reasons_missing': missing,
      'created_by_name': 'Ilham',
      'items': [
        {
          'id': 1,
          'material_id': 15,
          'item_name': 'Teh original',
          'system_qty': '1000',
          'physical_qty': '940',
          'returned_qty': '0',
          'diff': '-60',
          'unit': 'Ml',
          'stock_out': null,
          'max_shortage': '50',
          'verdict': 'unfair',
          'reason': reason,
          'initial_physical_qty': '930',
          'superseded_by': null,
        },
        {
          'id': 2,
          'material_id': 16,
          'item_name': 'Teh hijau',
          'system_qty': '990',
          'physical_qty': '1190',
          'diff': '200',
          'unit': 'Ml',
          'stock_out': '30',
          'max_shortage': '20',
          'verdict': 'fair',
          'reason': '',
        },
      ],
    };

AuditPeriods _periods({Map<String, dynamic>? daily, Map<String, dynamic>? weekly, int dailyListed = 2}) =>
    AuditPeriods.fromJson({
      'date': '2026-11-02',
      'periods': [
        {'audit_type': 'daily', 'period_key': '2026-11-02', 'listed_count': dailyListed, 'audit': daily},
        {'audit_type': 'weekly', 'period_key': '2026-W45', 'listed_count': 2, 'audit': weekly},
        {'audit_type': 'monthly', 'period_key': '2026-11', 'listed_count': 46, 'audit': null},
      ],
    });

class _Repo implements StockAuditRepository {
  StockAudit audit = StockAudit.fromJson(_auditJson());
  AuditPeriods periods = _periods();
  final reasonCalls = <List<Map<String, dynamic>>>[];
  int periodCalls = 0;

  @override
  Future<List<AuditableItem>> getAuditableItems({int? branchId, String type = AuditTypes.general}) async => [
        AuditableItem(type: 'material', materialId: 15, name: 'Teh original', unit: 'Ml', systemQty: 1000),
        AuditableItem(type: 'material', materialId: 16, name: 'Teh hijau', unit: 'Ml', systemQty: 990, incomingToday: 500),
      ];

  @override
  Future<StockAudit> getAudit(int id) async => audit;

  @override
  Future<StockAudit> setReasons(int id, List<Map<String, dynamic>> items) async {
    reasonCalls.add(items);
    audit = StockAudit.fromJson(_auditJson(reason: '${items.first['reason']}', missing: 0));
    return audit;
  }

  @override
  Future<AuditPeriods> getPeriods() async {
    periodCalls++;
    return periods;
  }

  @override
  Future<PageResult<StockAudit>> getAuditPage({required int page, required int limit}) async =>
      PageResult(items: [StockAudit.fromJson(_auditJson())], total: 1, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _pump(WidgetTester tester, Widget home, _Repo repo, {List<String> roles = const ['karyawan']}) async {
  // HP 360 × 800 dp. Tema app wajib ikut: tombol bertema lebar penuh pernah
  // hilang di dalam Row tanpa ketahuan tes (1 Nov 2026).
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(
        (ref) => _FixedAuth(AuthState(status: AuthStatus.authenticated, role: roles.first, roles: roles, branchId: 2)),
      ),
      stockAuditRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
}

Finder _button(String text) => find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('model', () {
    test('opname membawa jenis, periode, dan keterangan per barang', () {
      final a = StockAudit.fromJson(_auditJson());
      expect(a.auditType, AuditTypes.daily);
      expect(a.periodKey, '2026-11-02');
      expect(a.waitingReasons, isTrue);
      expect(a.createdByName, 'Ilham');
      final teh = a.items.first;
      expect(teh.isUnfair, isTrue);
      expect(teh.shortage, 60);
      expect(teh.maxShortage, 50);
      expect(teh.stockOut, isNull, reason: 'belum pernah diopname');
      expect(teh.physicalChanged, isTrue);
      expect(teh.idPayload, {'material_id': 15});
      expect(a.items[1].stockOut, 30);
    });

    test('opname lama tanpa kolom Tahap 5 tetap terbaca sebagai Umum', () {
      final a = StockAudit.fromJson({'id': 1, 'status': 'approved', 'items': []});
      expect(a.auditType, AuditTypes.general);
      expect(a.reasonsMissing, 0);
      expect(a.waitingReasons, isFalse);
    });

    test('penahan Shift 2: kosong, belum dibuat, belum beralasan, lengkap', () {
      expect(dailyAuditBlock(_periods(dailyListed: 0)), DailyAuditBlock.none, reason: 'daftar Harian kosong');
      expect(dailyAuditBlock(_periods()), DailyAuditBlock.missing);
      expect(
        dailyAuditBlock(_periods(daily: {'id': 41, 'status': 'draft', 'unfair_count': 1, 'reasons_missing': 1})),
        DailyAuditBlock.reasons,
      );
      expect(
        dailyAuditBlock(_periods(daily: {'id': 41, 'status': 'draft', 'unfair_count': 1, 'reasons_missing': 0})),
        DailyAuditBlock.none,
        reason: 'draf cukup, tidak harus disetujui',
      );
    });

    test('Shift 2 dikenali dari nama shift server', () {
      expect(ShiftModel.fromJson({'id': 1, 'shift_name': 'Shift 2', 'status': 'open'}).isSecondShift, isTrue);
      expect(ShiftModel.fromJson({'id': 1, 'shift_name': 'Shift 1', 'status': 'open'}).isSecondShift, isFalse);
      expect(ShiftModel.fromJson({'id': 1, 'status': 'open'}).isSecondShift, isFalse);
    });
  });

  group('form', () {
    testWidgets('opname harian: hitungan buta, tombol simpan terlihat', (tester) async {
      await _pump(tester, const StockAuditFormPage(auditType: AuditTypes.daily), _Repo());
      expect(tester.takeException(), isNull);
      expect(find.text('Opname Harian'), findsOneWidget);
      expect(find.text('Teh original'), findsOneWidget);
      expect(find.textContaining('Sistem'), findsNothing, reason: 'angka sistem tidak ditampilkan');
      expect(find.text('1000'), findsNothing);
      expect(find.text('Masuk hari ini: 500'), findsOneWidget);
      expect(find.textContaining('sengaja tidak'), findsOneWidget);
      final save = _button('Simpan Audit');
      expect(save, findsOneWidget);
      expect(tester.getRect(save).width, greaterThan(300));
    });
  });

  group('detail', () {
    testWidgets('barang tidak wajar: alasan wajib sebelum Setujui', (tester) async {
      final repo = _Repo();
      await _pump(tester, const StockAuditDetailPage(auditId: 41), repo, roles: ['supervisor']);
      expect(tester.takeException(), isNull);
      expect(find.text('Teh original: kurang 60 Ml, batas 50 Ml'), findsOneWidget);
      expect(find.text('1 barang tidak wajar · 1 belum diberi alasan'), findsOneWidget);
      expect(find.text('Harian · 2026-11-02'), findsOneWidget);
      expect(find.textContaining('Ilham'), findsOneWidget);
      final rows = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Fisik diubah dari 930'), 200, scrollable: rows);
      expect(find.text('Keluar 30'), findsOneWidget);
      expect(find.text('Batas 50 Ml'), findsOneWidget);
      expect(find.text('Tidak wajar'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Teh original: kurang 60 Ml, batas 50 Ml'), -200, scrollable: rows);

      // Tombol Setujui ada di luar daftar (bawah layar), selalu terlihat.
      final approve = _button('Setujui Audit');
      expect(tester.widget<ButtonStyleButton>(approve).onPressed, isNull, reason: 'alasan belum ada');
      expect(find.textContaining('Belum bisa disetujui'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Tumpah saat closing');
      await tester.pump();
      final save = _button('Simpan alasan');
      expect(tester.getRect(save).width, greaterThan(250));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.reasonCalls.single, [
        {'material_id': 15, 'reason': 'Tumpah saat closing'},
      ]);
      expect(tester.widget<ButtonStyleButton>(_button('Setujui Audit')).onPressed, isNotNull);
    });

    testWidgets('karyawan: alasan bisa diisi, tanpa tombol Setujui', (tester) async {
      await _pump(tester, const StockAuditDetailPage(auditId: 41), _Repo());
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Setujui Audit'), findsNothing);
    });

    testWidgets('sudah disetujui: alasan hanya dibaca', (tester) async {
      final repo = _Repo()..audit = StockAudit.fromJson(_auditJson(reason: 'Tumpah', status: 'approved', missing: 0));
      await _pump(tester, const StockAuditDetailPage(auditId: 41), repo, roles: ['supervisor']);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Alasan: Tumpah'), findsOneWidget);
    });
  });

  group('daftar', () {
    testWidgets('karyawan: kartu Harian & Mingguan, tanpa Bulanan', (tester) async {
      final repo = _Repo()
        ..periods = _periods(weekly: {'id': 9, 'status': 'draft', 'unfair_count': 1, 'reasons_missing': 1});
      await _pump(tester, const StockAuditListPage(), repo);
      expect(tester.takeException(), isNull);
      expect(find.text('Opname Harian'), findsOneWidget);
      expect(find.text('Belum dibuat'), findsOneWidget);
      expect(find.text('Opname Mingguan'), findsOneWidget);
      expect(find.text('Menunggu alasan'), findsWidgets);
      expect(find.text('Opname Bulanan'), findsNothing);
      expect(find.text('Opname Harian · 2026-11-02'), findsOneWidget, reason: 'kartu opname di daftar');
    });

    testWidgets('SPV melihat kartu Bulanan', (tester) async {
      await _pump(tester, const StockAuditListPage(), _Repo(), roles: ['supervisor']);
      expect(find.text('Opname Bulanan'), findsOneWidget);
    });
  });

  group('Tutup Shift 2', () {
    Future<bool?> runGate(WidgetTester tester, _Repo repo, {String tapLabel = 'Nanti'}) async {
      bool? result;
      await _pump(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => result = await ensureDailyAudit(context, ref),
                child: const Text('Tutup'),
              ),
            ),
          ),
        ),
        repo,
      );
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('opname harian lengkap: lanjut tanpa dialog', (tester) async {
      final repo = _Repo()
        ..periods = _periods(daily: {'id': 41, 'status': 'draft', 'unfair_count': 0, 'reasons_missing': 0});
      expect(await runGate(tester, repo), isTrue);
      expect(find.text('Opname harian dulu'), findsNothing);
    });

    testWidgets('belum dibuat: dialog, "Nanti" membatalkan tutup shift', (tester) async {
      final repo = _Repo();
      bool? result;
      await _pump(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => result = await ensureDailyAudit(context, ref),
                child: const Text('Tutup'),
              ),
            ),
          ),
        ),
        repo,
      );
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Opname harian dulu'), findsOneWidget);
      expect(find.text('Buka opname harian'), findsOneWidget);
      await tester.tap(find.text('Nanti'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('belum dibuat: tombol membuka form Opname Harian', (tester) async {
      final repo = _Repo();
      await _pump(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(onPressed: () => ensureDailyAudit(context, ref), child: const Text('Tutup')),
            ),
          ),
        ),
        repo,
      );
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka opname harian'));
      await tester.pumpAndSettle();
      expect(find.text('Opname Harian'), findsOneWidget);
    });

    testWidgets('belum beralasan: tombol membuka detail opname harian', (tester) async {
      final repo = _Repo()
        ..periods = _periods(daily: {'id': 41, 'status': 'draft', 'unfair_count': 1, 'reasons_missing': 1});
      await _pump(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(onPressed: () => ensureDailyAudit(context, ref), child: const Text('Tutup')),
            ),
          ),
        ),
        repo,
      );
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Lengkapi alasan opname harian'), findsOneWidget);
      await tester.tap(find.text('Lengkapi alasan'));
      await tester.pumpAndSettle();
      expect(find.text('Teh original: kurang 60 Ml, batas 50 Ml'), findsOneWidget);
    });

    testWidgets('status gagal dibaca: lanjut, server tetap penentunya', (tester) async {
      final repo = _FailingRepo();
      expect(await runGate(tester, repo), isTrue);
    });
  });
}

class _FailingRepo extends _Repo {
  @override
  Future<AuditPeriods> getPeriods() async => throw 'jaringan putus';
}
