import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/data/repositories/shift_repository.dart';
import 'package:pos_mobile/data/repositories/stock_audit_repository.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/presentation/pages/stock_audits/daily_audit_gate.dart';
import 'package:pos_mobile/presentation/pages/stock_audits/stock_audit_detail_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_audit_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Revisi 19 Nov gelombang 1, app kasir: buka shift ditolak selama opname belum
// di-ACC (dialog, bukan snackbar), dan keterangan penyesuaian saat fisik lebih
// banyak dari sistem.

class _FakeAdapter implements HttpClientAdapter {
  int status = 200;
  Object? body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _gulaMerah({required String status}) => {
      'id': 521,
      'created_by': 1,
      'status': status,
      'notes': '',
      'audit_type': 'general',
      'counted_at': '2026-11-14T23:30:00+07:00',
      'unfair_count': 0,
      'reasons_missing': 0,
      'items': [
        {
          'id': 1,
          'material_id': 17,
          'item_name': 'Gula Merah',
          'system_qty': '1214',
          'physical_qty': '4000',
          'returned_qty': '1681',
          'diff': '4467',
          'unit': 'gram',
          'reason': '',
        },
      ],
    };

class _Repo implements StockAuditRepository {
  StockAudit audit = StockAudit.fromJson(_gulaMerah(status: 'draft'));
  @override
  Future<StockAudit> getAudit(int id) async => audit;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _pump(WidgetTester tester, Widget home, _Repo repo) async {
  // HP 360 × 800 dp dengan tema app (tombol bertema pernah hilang tanpa ketahuan tes).
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(
        (ref) => _FixedAuth(AuthState(status: AuthStatus.authenticated, role: 'leader', roles: const ['leader'], branchId: 12)),
      ),
      stockAuditRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  group('buka shift', () {
    late _FakeAdapter adapter;
    late ShiftRepository repo;
    setUp(() {
      adapter = _FakeAdapter();
      repo = ShiftRepository(ApiService()..dio.httpClientAdapter = adapter);
    });

    test('422 audit_pending jadi AuditPending dengan id opname', () async {
      adapter
        ..status = 422
        ..body = {
          'success': false,
          'code': 'audit_pending',
          'message': 'Kasir belum bisa dibuka: opname harian 18 Nov 2026 (#521) belum di-ACC. Minta SPV atau owner meng-ACC opname itu dulu.',
          'data': {'audit_id': 521, 'audit_type': 'daily', 'period_key': '2026-11-18', 'period': 'harian 18 Nov 2026'},
        };
      await expectLater(
        repo.open(),
        throwsA(isA<AuditPending>()
            .having((e) => e.auditId, 'auditId', 521)
            .having((e) => e.message, 'message', contains('(#521)'))),
      );
    });

    test('galat lain tetap pesan server', () async {
      adapter
        ..status = 409
        ..body = {'success': false, 'message': 'shift already open for this branch'};
      await expectLater(repo.open(), throwsA('shift already open for this branch'));
    });
  });

  group('dialog opname belum di-ACC', () {
    testWidgets('menjelaskan dan membuka detail opname', (tester) async {
      final repo = _Repo();
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAuditPending(context, 'Kasir belum bisa dibuka: opname umum 14 Nov 2026 (#521) belum di-ACC.', 521),
                child: const Text('Buka shift'),
              ),
            ),
          ),
        ),
        repo,
      );
      await tester.tap(find.text('Buka shift'));
      await tester.pumpAndSettle();
      expect(find.text('Opname belum di-ACC'), findsOneWidget);
      expect(find.textContaining('(#521) belum di-ACC'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);
      await tester.tap(find.text('Lihat opname'));
      await tester.pumpAndSettle();
      expect(find.byType(StockAuditDetailPage), findsOneWidget);
      expect(find.text('Gula Merah'), findsOneWidget);
    });

    testWidgets('tanpa id opname: hanya tombol Tutup', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(onPressed: () => showAuditPending(context, 'Opname belum di-ACC.', null), child: const Text('Buka shift')),
            ),
          ),
        ),
        _Repo(),
      );
      await tester.tap(find.text('Buka shift'));
      await tester.pumpAndSettle();
      expect(find.text('Lihat opname'), findsNothing);
      expect(find.text('Tutup'), findsOneWidget);
    });
  });

  group('detail opname', () {
    testWidgets('draf: selisih lebih diajukan sebagai penyesuaian, retur terkirim penuh', (tester) async {
      await _pump(tester, const StockAuditDetailPage(auditId: 521), _Repo());
      expect(find.textContaining('Lebih 4467 dari sistem: diajukan sebagai penyesuaian, sah saat SPV ACC'), findsOneWidget);
      expect(find.textContaining('retur 1681 ikut terkirim penuh'), findsOneWidget);
      expect(find.textContaining('perlu diperiksa'), findsNothing);
    });

    testWidgets('sudah di-ACC: keterangan penyesuaian tidak tampil lagi', (tester) async {
      final repo = _Repo()..audit = StockAudit.fromJson(_gulaMerah(status: 'approved'));
      await _pump(tester, const StockAuditDetailPage(auditId: 521), repo);
      expect(find.textContaining('diajukan sebagai penyesuaian'), findsNothing);
    });
  });
}
