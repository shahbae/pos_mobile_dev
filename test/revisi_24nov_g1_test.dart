import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/leave_out_model.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/data/models/overtime_model.dart';
import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/presentation/pages/attendance/attendance_page.dart';
import 'package:pos_mobile/presentation/pages/attendance/leave_out_card.dart';
import 'package:pos_mobile/presentation/pages/schedules/my_schedule_page.dart';
import 'package:pos_mobile/presentation/pages/shifts/shift_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/shift_provider.dart';
import 'package:pos_mobile/presentation/widgets/setting_menu_card.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Revisi owner 24 Nov 2026, langkah 1 (app kasir): Izin keluar pindah ke
/// Pengaturan di atas Logout, kartu lembur pindah ke Jadwal Saya, dan Kas
/// Seharusnya tak tampil di kartu shift aktif.

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  Future<bool> refreshSession() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthState _auth(List<String> roles) =>
    AuthState(status: AuthStatus.authenticated, role: roles.first, roles: roles, branchId: 2);

Widget _host(Widget page, List<String> roles, List<Override> extra) => ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FixedAuth(_auth(roles))),
        ...extra,
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: page))),
    );

Widget _screen(Widget page, List<String> roles, List<Override> extra) => ProviderScope(
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

/// App kasir dipakai di tablet; huruf uji (Ahem) juga lebih lebar dari aslinya.
Future<void> _tablet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _att() => {
      'id': 40,
      'user_id': 6,
      'branch_id': 2,
      'attendance_date': '2026-11-03',
      'shift': 'shift_1',
      'check_in_at': '2026-11-03T07:05:00+07:00',
      'check_in_status': 'valid',
      'schedule_id': 31,
      'late_minutes': 0,
      'checkout_past_limit': false,
      'overtime': null,
    };

MyDay _day({bool working = true}) => MyDay.fromJson({
      'date': '2026-11-03',
      'now': '2026-11-03T07:05:00+07:00',
      'checkin_open_minutes': 20,
      'shifts': const [],
      'attendances': working ? [_att()] : const [],
      'open_attendance_id': working ? 40 : null,
      'has_next_shift': false,
    }, receivedAt: DateTime.now());

final _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

ScheduledOvertime _overtime() => ScheduledOvertime.fromJson({
      'id': 5,
      'user_id': 42,
      'user_name': 'Crew',
      'date': _today,
      'home': {'type': 'branch', 'id': 12, 'name': 'JUNTIKEBON'},
      'location': {'type': 'branch', 'id': 12, 'name': 'JUNTIKEBON'},
      'cross_location': false,
      'start_time': '16:41',
      'end_time': '19:41',
      'status': 'scheduled',
      'hours': 0,
    });

ShiftModel _openShift() => ShiftModel.fromJson({
      'id': 110,
      'status': 'open',
      'opening_cash': 200000,
      'total_sales': 40000,
      'cash_sales': 40000,
      'total_expense': 0,
      'expected_cash': 240000,
      'opened_at': '2026-11-22T20:17:00+07:00',
    });

VoidCallback? _cardTap(WidgetTester tester) => tester
    .widget<InkWell>(find.descendant(of: find.byType(SettingMenuCard), matching: find.byType(InkWell)))
    .onTap;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  group('Izin keluar di Pengaturan', () {
    List<Override> over(MyDay day, List<OnDutyModel> duty) => [
          myDayProvider.overrideWith((ref) async => day),
          onDutyProvider.overrideWith((ref, _) async => duty),
        ];

    testWidgets('belum absen masuk: kartu ada tetapi nonaktif dan menjelaskan kenapa', (tester) async {
      await tester.pumpWidget(_host(const LeaveOutMenuCard(), ['karyawan'], over(_day(working: false), const [])));
      await tester.pumpAndSettle();
      expect(find.text('Izin keluar sebentar'), findsOneWidget);
      expect(find.textContaining('Hanya saat sedang bertugas'), findsOneWidget);
      expect(_cardTap(tester), isNull);
    });

    testWidgets('sedang bertugas: bisa diketuk, rekan serah tugas tanpa dirinya', (tester) async {
      await tester.pumpWidget(_host(
        const LeaveOutMenuCard(),
        ['karyawan'],
        over(_day(), const [
          OnDutyModel(attendanceId: 40, userId: 6, userName: 'Citra'),
          OnDutyModel(attendanceId: 41, userId: 7, userName: 'Dewi'),
        ]),
      ));
      await tester.pumpAndSettle();
      expect(_cardTap(tester), isNotNull);
      await tester.tap(find.text('Izin keluar sebentar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tanpa serah tugas'));
      await tester.pumpAndSettle();
      expect(find.text('Dewi'), findsWidgets);
      expect(find.text('Citra'), findsNothing);
    });

    testWidgets('sedang izin keluar: kartunya jadi "Saya sudah kembali"', (tester) async {
      await tester.pumpWidget(_host(
        const LeaveOutMenuCard(),
        ['karyawan'],
        over(_day(), const [OnDutyModel(attendanceId: 40, userId: 6, userName: 'Citra', leaveOutId: 9)]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Saya sudah kembali'), findsOneWidget);
      expect(find.text('Izin keluar sebentar'), findsNothing);
      expect(_cardTap(tester), isNotNull);
    });
  });

  group('Halaman Absensi tidak lagi memuat izin keluar dan kartu lembur', () {
    List<Override> over() => [
          myDayProvider.overrideWith((ref) async => _day()),
          onDutyProvider.overrideWith((ref, _) async => const []),
          myOvertimesProvider.overrideWith((ref) async => [_overtime()]),
        ];

    testWidgets('role biasa: tanpa Izin keluar sebentar dan tanpa Ada jadwal lembur', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_screen(const AttendancePage(), ['karyawan'], over()));
      await tester.pumpAndSettle();
      expect(find.text('Absen Pulang'), findsOneWidget);
      expect(find.text('Izin keluar sebentar'), findsNothing);
      expect(find.text('Ada jadwal lembur'), findsNothing);
    });

    testWidgets('role absensi-saja (finance, isRoot): kartu lembur tetap ada di sini', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_screen(const AttendancePage(isRoot: true), ['finance'], over()));
      await tester.pumpAndSettle();
      expect(find.text('Ada jadwal lembur'), findsOneWidget);
    });
  });

  group('Jadwal Saya', () {
    testWidgets('memuat kartu lembur terjadwal', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_screen(const MySchedulePage(), ['karyawan'], [
        mySchedulesProvider.overrideWith((ref) async => const []),
        myOvertimesProvider.overrideWith((ref) async => [_overtime()]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Ada jadwal lembur'), findsOneWidget);
      expect(find.text('Absen Lembur'), findsOneWidget);
    });

    testWidgets('tanpa lembur: kartu tidak tampil', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_screen(const MySchedulePage(), ['karyawan'], [
        mySchedulesProvider.overrideWith((ref) async => const []),
        myOvertimesProvider.overrideWith((ref) async => const <ScheduledOvertime>[]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Ada jadwal lembur'), findsNothing);
    });
  });

  group('Kas Seharusnya di kartu shift aktif', () {
    for (final role in ['karyawan', 'leader', 'supervisor', 'owner']) {
      testWidgets('$role: tidak tampil', (tester) async {
        await _tablet(tester);
        await tester.pumpWidget(_screen(const ShiftPage(), [role], [
          currentShiftProvider.overrideWith((ref) async => _openShift()),
          attendanceGateProvider.overrideWith((ref) async => AttendanceGateStatus.working),
        ]));
        await tester.pumpAndSettle();
        expect(find.text('Kas Awal'), findsOneWidget);
        expect(find.text('Penjualan Tunai'), findsOneWidget);
        expect(find.text('Kas Seharusnya'), findsNothing);
      });
    }
  });
}
