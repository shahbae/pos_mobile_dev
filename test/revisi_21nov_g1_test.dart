import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/presentation/pages/shifts/shift_list_page.dart';
import 'package:pos_mobile/presentation/pages/shifts/shift_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/shift_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Revisi owner 21 Nov 2026, fase 1: semua akun masuk aplikasi, yang dikunci
/// hanya Buka Shift sampai absen masuk (owner bebas); kasir tidak melihat Kas
/// Seharusnya dan Selisih.

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  Future<bool> refreshSession() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthState _auth(List<String> roles) => AuthState(
      status: AuthStatus.authenticated,
      role: roles.first,
      roles: roles,
      branchId: 2,
    );

Widget _host(Widget page, List<String> roles, List<Override> extra) => ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FixedAuth(_auth(roles))),
        ...extra,
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: page),
    );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// ElevatedButton.icon adalah subkelas privat, jadi dicari lewat predikat.
Finder _btn(String text) =>
    find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ElevatedButton));

ShiftModel _closedShift() => ShiftModel.fromJson({
      'id': 9,
      'status': 'closed',
      'opening_cash': 400000,
      'closing_cash': 832000,
      'total_sales': 596000,
      'cash_sales': 548000,
      'total_expense': 116000,
      'expected_cash': 832000,
      'difference': 0,
      'opened_at': '2026-11-18T07:00:00+07:00',
      'closed_at': '2026-11-18T14:05:00+07:00',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  group('aturan peran', () {
    test('buka shift wajib absen: semua kecuali owner', () {
      for (final held in [
        {'karyawan'},
        {'kasir'},
        {'leader'},
        {'supervisor'},
        {'finance', 'leader'},
      ]) {
        expect(mustCheckInToOpenShift(held), isTrue, reason: '$held');
      }
      expect(mustCheckInToOpenShift({'owner'}), isFalse);
      expect(mustCheckInToOpenShift({'owner', 'karyawan'}), isFalse);
    });

    test('Kas Seharusnya & Selisih: leader ke atas dan finance', () {
      expect(canSeeCashDifference({'karyawan'}), isFalse);
      expect(canSeeCashDifference({'kasir'}), isFalse);
      for (final r in ['owner', 'supervisor', 'leader', 'finance']) {
        expect(canSeeCashDifference({r, 'karyawan'}), isTrue, reason: r);
      }
    });
  });

  group('kartu Buka Shift', () {
    List<Override> noShift(AttendanceGateStatus s) => [
          currentShiftProvider.overrideWith((ref) async => null),
          attendanceGateProvider.overrideWith((ref) async => s),
        ];

    testWidgets('kasir belum absen: tombolnya Absen Masuk, bukan Buka Shift', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_host(const ShiftPage(), ['karyawan'], noShift(AttendanceGateStatus.notCheckedIn)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Absen masuk dulu sebelum buka shift'), findsOneWidget);
      expect(_btn('Absen Masuk'), findsOneWidget);
      expect(_btn('Buka Shift'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leader sudah absen pulang: tetap terkunci', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_host(const ShiftPage(), ['leader'], noShift(AttendanceGateStatus.checkedOut)));
      await tester.pumpAndSettle();
      expect(_btn('Absen Masuk'), findsOneWidget);
    });

    testWidgets('kasir sedang absen: Buka Shift terbuka', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_host(const ShiftPage(), ['karyawan'], noShift(AttendanceGateStatus.working)));
      await tester.pumpAndSettle();
      expect(_btn('Buka Shift'), findsOneWidget);
      expect(_btn('Absen Masuk'), findsNothing);
    });

    testWidgets('owner tanpa absen: Buka Shift terbuka', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_host(const ShiftPage(), ['owner'], noShift(AttendanceGateStatus.notCheckedIn)));
      await tester.pumpAndSettle();
      expect(_btn('Buka Shift'), findsOneWidget);
    });
  });

  group('riwayat shift buta', () {
    List<Override> list() => [shiftListProvider.overrideWith((ref) async => [_closedShift()])];

    testWidgets('kasir: tanpa Kas Seharusnya dan Selisih', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_host(const ShiftListPage(), ['karyawan'], list()));
      await tester.pumpAndSettle();
      expect(find.text('Kas Akhir'), findsOneWidget);
      expect(find.text('Kas Seharusnya'), findsNothing);
      expect(find.textContaining('Selisih'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leader: Kas Seharusnya dan Selisih tampil', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_host(const ShiftListPage(), ['leader'], list()));
      await tester.pumpAndSettle();
      expect(find.text('Kas Seharusnya'), findsOneWidget);
      expect(find.textContaining('Selisih'), findsOneWidget);
    });
  });
}
