import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/presentation/pages/shipments/shipment_detail_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/presentation/widgets/attendance_gate.dart';
import 'package:pos_mobile/theme/app_theme.dart';

AttendanceModel _att({bool checkedOut = false}) => AttendanceModel.fromJson({
      'id': 1,
      'user_id': 3,
      'branch_id': 7,
      'attendance_date': '2026-10-17',
      'shift': 'shift_1',
      'check_in_at': '2026-10-17T07:00:00+07:00',
      if (checkedOut) 'check_out_at': '2026-10-17T15:05:00+07:00',
    });

Widget _gate(AttendanceGateStatus s) => ProviderScope(
      overrides: [
        attendanceGateProvider.overrideWith((ref) async => s),
        // Halaman Absensi membaca status hari ini sendiri.
        attendanceTodayProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AttendanceGate(child: Scaffold(body: Text('DASHBOARD'))),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(
      fileName: '.env',
      isOptional: true,
      mergeWith: {'API_BASE_URL': 'http://localhost'},
    );
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  group('siapa yang terkunci', () {
    test('semua yang ikut absen; owner tidak', () {
      for (final r in ['kasir', 'leader', 'supervisor', 'produksi']) {
        expect(requiresAttendanceGate(r), isTrue, reason: r);
      }
      expect(requiresAttendanceGate('owner'), isFalse);
      // Absensi-saja sudah mendarat di halaman Absensi.
      expect(requiresAttendanceGate('finance'), isFalse);
    });

    test('status dari absensi hari ini', () {
      expect(gateStatusOf(null), AttendanceGateStatus.notCheckedIn);
      expect(gateStatusOf(_att()), AttendanceGateStatus.working);
      expect(gateStatusOf(_att(checkedOut: true)), AttendanceGateStatus.checkedOut);
    });
  });

  group('cadangan saat server tak terjangkau', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('status tersimpan hanya berlaku untuk tanggal yang sama', () async {
      await AttendanceGateCache.write('2026-10-17', AttendanceGateStatus.checkedOut);
      expect(await AttendanceGateCache.read('2026-10-17'), AttendanceGateStatus.checkedOut);
      expect(await AttendanceGateCache.read('2026-10-18'), isNull);
    });
  });

  group('layar penguncian', () {
    testWidgets('belum absen masuk → halaman Absensi dengan penjelasan', (tester) async {
      await tester.pumpWidget(_gate(AttendanceGateStatus.notCheckedIn));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.textContaining('Absen masuk dulu untuk mulai bekerja'), findsOneWidget);
      expect(find.text('Absen Masuk'), findsWidgets);
    });

    testWidgets('sudah absen pulang → terkunci, ada jalan muat ulang', (tester) async {
      await tester.pumpWidget(_gate(AttendanceGateStatus.checkedOut));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.text('Kamu sudah absen pulang hari ini'), findsOneWidget);
      expect(find.text('Muat ulang'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sedang bekerja → aplikasi terbuka', (tester) async {
      await tester.pumpWidget(_gate(AttendanceGateStatus.working));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
    });
  });

  group('shift & kiriman', () {
    test('pemilik shift terbaca dari cashier_id', () {
      final s = ShiftModel.fromJson({'id': 1, 'status': 'open', 'cashier_id': 3, 'opening_cash': 0, 'total_sales': 0});
      expect(s.isOpen, isTrue);
      expect(s.cashierId, 3);
    });

    test('kiriman membawa revisi & alasan ubah', () {
      final sh = Shipment.fromJson({
        'id': 3, 'branch_id': 7, 'stock_request_id': 5, 'status': 'shipped',
        'revision': 2, 'edit_reason': 'stok teh tipis', 'edited_at': '2026-10-17T09:00:00Z',
      });
      expect(sh.revision, 2);
      expect(sh.wasEdited, isTrue);
      expect(sh.editReason, 'stok teh tipis');

      final lama = Shipment.fromJson({'id': 3, 'branch_id': 7, 'stock_request_id': 5, 'status': 'shipped'});
      expect(lama.revision, 0);
      expect(lama.wasEdited, isFalse);
    });

    testWidgets('detail menampilkan bahwa isinya diubah gudang', (tester) async {
      final sh = Shipment(
        id: 3, branchId: 7, branchName: 'Cabang Sudirman', stockRequestId: 5,
        status: 'shipped', revision: 1, editReason: 'stok teh tipis',
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [shipmentDetailProvider(sh.id).overrideWith((ref) async => sh)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: ShipmentDetailPage(shipmentId: sh.id)),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('diubah gudang: stok teh tipis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
