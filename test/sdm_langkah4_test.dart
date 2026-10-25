import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/leave_out_model.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/data/models/schedule_model.dart';
import 'package:pos_mobile/data/models/profile_model.dart';
import 'package:pos_mobile/presentation/pages/attendance/attendance_page.dart';
import 'package:pos_mobile/presentation/pages/attendance/leave_out_list_page.dart';
import 'package:pos_mobile/presentation/pages/attendance/on_duty_page.dart';
import 'package:pos_mobile/presentation/pages/profile/profile_page.dart';
import 'package:pos_mobile/presentation/pages/schedules/my_schedule_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/duty_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Tahap 1 SDM, langkah 4: app kasir mengikuti jadwal.
///
/// Contoh orangnya: Citra (karyawan) dijadwalkan di Karangampel (cabang 2),
/// Shift 1 07.00–15.00. Hari ini jam server 07.05.

const _now = '2026-11-03T07:05:00+07:00';

Map<String, dynamic> _code(int id, String name, String start, String end) => {
      'id': id,
      'name': name,
      'short_name': 'S$id',
      'kind': 'work',
      'start_time': start,
      'end_time': end,
      'checkout_limit': null,
    };

Map<String, dynamic> _shift({
  int id = 31,
  String name = 'Shift 1',
  String start = '07:00',
  String end = '15:00',
  String duty = 'cashier',
  int branch = 2,
  required String status,
  int? attendanceId,
}) =>
    {
      'schedule_id': id,
      'date': '2026-11-03',
      'shift_code': _code(id == 31 ? 1 : 2, name, start, end),
      'duty': duty,
      'location': {'type': 'branch', 'id': branch, 'name': branch == 2 ? 'Karangampel' : 'Pusat'},
      'opens_at': '2026-11-03T${_minus20(start)}:00+07:00',
      'starts_at': '2026-11-03T$start:00+07:00',
      'ends_at': '2026-11-03T$end:00+07:00',
      'status': status,
      'attendance_id': attendanceId,
    };

String _minus20(String hhmm) {
  final h = int.parse(hhmm.substring(0, 2));
  final m = int.parse(hhmm.substring(3));
  final t = h * 60 + m - 20;
  return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
}

Map<String, dynamic> _att({
  int id = 40,
  int scheduleId = 31,
  bool out = false,
  int late = 5,
}) =>
    {
      'id': id,
      'user_id': 6,
      'branch_id': 2,
      'attendance_date': '2026-11-03',
      'shift': 'shift_1',
      'check_in_at': '2026-11-03T07:05:00+07:00',
      'check_in_status': 'valid',
      if (out) 'check_out_at': '2026-11-03T15:02:00+07:00',
      'schedule_id': scheduleId,
      'late_minutes': late,
      'checkout_past_limit': false,
      'schedule': {
        'schedule_id': scheduleId,
        'shift_code_id': 1,
        'shift_name': 'Shift 1',
        'short_name': 'S1',
        'duty': 'cashier',
        'start_time': '07:00',
        'end_time': '15:00',
        'checkout_limit': '15:50',
      },
      'overtime': null,
    };

MyDay _day({
  List<Map<String, dynamic>> shifts = const [],
  List<Map<String, dynamic>> atts = const [],
  int? open,
  bool next = false,
  String now = _now,
}) =>
    MyDay.fromJson({
      'date': '2026-11-03',
      'now': now,
      'checkin_open_minutes': 20,
      'shifts': shifts,
      'attendances': atts,
      'open_attendance_id': open,
      'has_next_shift': next,
    }, receivedAt: DateTime.now());

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  Future<bool> refreshSession() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthState _auth(List<String> roles, {int? branchId = 2}) => AuthState(
      status: AuthStatus.authenticated,
      role: roles.first,
      roles: roles,
      branchId: branchId,
    );

Widget _page(MyDay day, {AuthState? auth, List<OnDutyModel> onDuty = const []}) => ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FixedAuth(auth ?? _auth(['karyawan']))),
        myDayProvider.overrideWith((ref) async => day),
        onDutyProvider.overrideWith((ref, _) async => onDuty),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const AttendancePage()),
    );

/// Tombol yang memuat [label]. `ElevatedButton.icon` adalah subkelas, jadi
/// dicari lewat leluhurnya.
ButtonStyleButton _button(WidgetTester tester, String label) => tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
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

  group('jawaban server', () {
    test('hari saya terbaca utuh', () {
      final d = _day(
        shifts: [_shift(status: 'checked_in', attendanceId: 40)],
        atts: [_att()],
        open: 40,
      );
      expect(d.shifts.single.title, 'Shift 1 · Kasir · 07.00–15.00');
      expect(d.shifts.single.location.name, 'Karangampel');
      expect(d.shifts.single.status, MyDayShiftStatus.checkedIn);
      expect(d.openAttendance?.id, 40);
      final a = d.attendances.single;
      expect(a.scheduleId, 31);
      expect(a.lateMinutes, 5);
      expect(a.shiftLabel, 'Shift 1');
      expect(a.schedule?.hours, '07.00–15.00');
    });

    test('absen lama tanpa jadwal tetap terbaca', () {
      final a = AttendanceModel.fromJson({
        'id': 1,
        'user_id': 3,
        'attendance_date': '2026-10-17',
        'shift': 'shift_2',
        'check_in_at': '2026-10-17T15:00:00+07:00',
      });
      expect(a.scheduleId, isNull);
      expect(a.checkoutPastLimit, isFalse);
      expect(a.shiftLabel, 'Shift 2 (Sore)');
    });

    test('lembur dengan menitnya', () {
      final a = AttendanceModel.fromJson({
        ..._att(out: true),
        'overtime': {'marked_by': 3, 'marked_by_name': 'Khaerudien', 'marked_at': _now, 'minutes': 100},
      });
      expect(a.overtime?.minutes, 100);
      expect(a.overtime?.markedByName, 'Khaerudien');
    });

    test('server lama tanpa /me/day: disusun dari absen hari ini', () {
      final open = MyDay.fromToday(AttendanceModel.fromJson(_att()));
      expect(open.openAttendance?.id, 40);
      expect(gateStatusOfDay(open), AttendanceGateStatus.working);
      expect(gateStatusOfDay(MyDay.fromToday(null)), AttendanceGateStatus.notCheckedIn);
      final done = MyDay.fromToday(AttendanceModel.fromJson(_att(out: true)));
      expect(gateStatusOfDay(done), AttendanceGateStatus.checkedOut);
    });

    test('jadwal saya: mulai hari ini, dobel shift satu tanggal', () {
      MyScheduleEntry e(int id, String date, String name) => MyScheduleEntry.fromJson({
            'id': id,
            'date': date,
            'duty': 'cashier',
            'shift_code': _code(1, name, '07:00', '15:00'),
            'location': {'type': 'branch', 'id': 2, 'name': 'Karangampel'},
          });
      final groups = groupFromToday([
        e(1, '2026-11-02', 'Shift 1'),
        e(2, '2026-11-03', 'Shift 1'),
        e(3, '2026-11-03', 'Shift 2'),
        e(4, '2026-11-04', 'Shift 1'),
      ], '2026-11-03');
      expect(groups.map((g) => g.key), ['2026-11-03', '2026-11-04']);
      expect(groups.first.value.length, 2);
    });
  });

  group('kunci aplikasi', () {
    test('sedang bekerja → terbuka', () {
      final d = _day(shifts: [_shift(status: 'checked_in', attendanceId: 40)], atts: [_att()], open: 40);
      expect(gateStatusOfDay(d), AttendanceGateStatus.working);
    });

    test('pulang shift 1, shift 2 masih ada → kembali ke Absensi, tidak terkunci', () {
      final d = _day(
        shifts: [
          _shift(status: 'done', attendanceId: 40),
          _shift(id: 32, name: 'Shift 2', start: '15:00', end: '23:00', status: 'upcoming'),
        ],
        atts: [_att(out: true)],
        next: true,
      );
      expect(gateStatusOfDay(d), AttendanceGateStatus.notCheckedIn);
    });

    test('pulang dan tidak ada shift lagi → terkunci sampai besok', () {
      final d = _day(shifts: [_shift(status: 'done', attendanceId: 40)], atts: [_att(out: true)]);
      expect(gateStatusOfDay(d), AttendanceGateStatus.checkedOut);
    });

    test('karyawan ikut terkunci; leader yang juga karyawan tidak', () {
      expect(requiresAttendanceGate({'karyawan'}), isTrue);
      expect(requiresAttendanceGate({'karyawan', 'leader'}), isFalse);
      expect(requiresAttendanceGate({'kasir'}), isTrue);
    });
  });

  group('jam buka absen', () {
    test('tombol menyala sendiri saat jendela dibuka, mati saat shift berakhir', () {
      final s = MyDayShift.fromJson(_shift(id: 32, name: 'Shift 2', start: '15:00', end: '23:00', status: 'upcoming'));
      expect(s.statusAt(DateTime.parse('2026-11-03T14:39:00+07:00')), MyDayShiftStatus.upcoming);
      expect(s.statusAt(DateTime.parse('2026-11-03T14:40:00+07:00')), MyDayShiftStatus.open);
      expect(s.statusAt(DateTime.parse('2026-11-03T23:00:00+07:00')), MyDayShiftStatus.missed);
    });

    test('shift berjalan dipilih lebih dulu dari shift berikutnya', () {
      final d = _day(shifts: [
        _shift(status: 'open'),
        _shift(id: 32, name: 'Shift 2', start: '15:00', end: '23:00', status: 'upcoming'),
      ], next: true);
      expect(d.currentShift?.scheduleId, 31);
      expect(d.nextShift?.scheduleId, 32);
    });
  });

  group('tugas kasir / penyaji', () {
    test('dibaca dari shift di cabang token', () {
      final penyaji = _day(shifts: [_shift(status: 'open', duty: 'server')]);
      expect(cashierDutyOf(penyaji, 2), isFalse);
      final keduanya = _day(shifts: [_shift(status: 'open', duty: 'both')]);
      expect(cashierDutyOf(keduanya, 2), isTrue);
      // Dobel shift: penyaji pagi, kasir sore → POS terbuka (server menilai sama).
      final campur = _day(shifts: [
        _shift(status: 'open', duty: 'server'),
        _shift(id: 32, name: 'Shift 2', start: '15:00', end: '23:00', status: 'upcoming', duty: 'cashier'),
      ]);
      expect(cashierDutyOf(campur, 2), isTrue);
      // Tidak ada jadwal di cabang ini: tidak dibatasi app; server yang menilai.
      expect(cashierDutyOf(penyaji, 8), isNull);
    });

    test('penyaji kehilangan POS, shift kasir, opname, riwayat penjualan', () {
      final f = featuresForToday('karyawan', {'karyawan'}, cashierDuty: false);
      expect(f.intersection(cashierDutyFeatures), isEmpty);
      expect(f, contains(AppFeature.kitchenDisplay));
      expect(f, contains(AppFeature.attendance));
    });

    test('bertugas kasir, tidak diketahui, atau bukan karyawan murni: tidak dikurangi', () {
      expect(featuresForToday('karyawan', {'karyawan'}, cashierDuty: true), contains(AppFeature.pos));
      expect(featuresForToday('karyawan', {'karyawan'}), contains(AppFeature.pos));
      // Kasir lama tidak diperiksa tugasnya sampai rolenya dimigrasi.
      expect(featuresForToday('kasir', {'kasir', 'karyawan'}, cashierDuty: false), contains(AppFeature.pos));
      expect(featuresForToday('leader', {'leader', 'karyawan'}, cashierDuty: false), contains(AppFeature.pos));
    });

    test('karyawan bertugas kasir mendapat opname', () {
      expect(featuresForToday('karyawan', {'karyawan'}, cashierDuty: true), contains(AppFeature.stockAudit));
      expect(canCreateAudit('karyawan'), isTrue);
    });

    test('tugas tersimpan per tanggal dan cabang untuk jualan offline', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await DutyCache.write('2026-11-03', 2, false);
      expect(await DutyCache.read('2026-11-03', 2), isFalse);
      expect(await DutyCache.read('2026-11-03', 8), isNull);
      expect(await DutyCache.read('2026-11-04', 2), isNull);
    });
  });

  group('hak per role', () {
    test('lembur & riwayat izin keluar: leader, SPV, owner', () {
      for (final r in ['leader', 'supervisor', 'owner']) {
        expect(canMarkOvertime({r}), isTrue, reason: r);
        expect(canSeeLeaveOuts({r}), isTrue, reason: r);
      }
      for (final r in ['kasir', 'karyawan', 'produksi']) {
        expect(canMarkOvertime({r}), isFalse, reason: r);
      }
    });

    test('izin keluar: yang bertugas di outlet', () {
      expect(canLeaveOut({'karyawan'}), isTrue);
      expect(canLeaveOut({'kasir'}), isTrue);
      expect(canLeaveOut({'produksi'}), isFalse);
    });

    test('isDutyGated hanya karyawan murni', () {
      expect(isDutyGated({'karyawan'}), isTrue);
      expect(isDutyGated({'karyawan', 'kasir'}), isFalse);
      expect(isDutyGated({'karyawan', 'produksi'}), isFalse);
      expect(isDutyGated({'kasir'}), isFalse);
    });
  });

  group('layar Absensi', () {
    testWidgets('shift terbuka: absen tanpa memilih shift', (tester) async {
      await tester.pumpWidget(_page(_day(shifts: [_shift(status: 'open')], next: true)));
      await tester.pumpAndSettle();
      expect(find.text('Shift 1 · Kasir · 07.00–15.00'), findsOneWidget);
      expect(find.textContaining('Absen masuk Shift 1 di Karangampel'), findsOneWidget);
      expect(find.text('Shift 1 (Pagi)'), findsNothing, reason: 'pilihan shift hilang');
      final btn = _button(tester, 'Absen Masuk');
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('jendela belum dibuka: tombol mati dan jam bukanya disebut', (tester) async {
      await tester.pumpWidget(_page(_day(
        shifts: [_shift(id: 32, name: 'Shift 2', start: '15:00', end: '23:00', status: 'upcoming')],
        next: true,
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('dibuka jam 14.40'), findsOneWidget);
      final btn = _button(tester, 'Absen Masuk');
      expect(btn.onPressed, isNull);
    });

    testWidgets('tanpa jadwal: memilih shift seperti dulu', (tester) async {
      await tester.pumpWidget(_page(_day()));
      await tester.pumpAndSettle();
      expect(find.text('Shift 1 (Pagi)'), findsOneWidget);
      expect(find.text('Shift 2 (Sore)'), findsOneWidget);
    });

    testWidgets('kasir tanpa cabang (tidak terjadwal): diminta hubungi leader', (tester) async {
      await tester.pumpWidget(_page(_day(), auth: _auth(['kasir'], branchId: null)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Belum ada jadwal hari ini'), findsOneWidget);
      expect(find.text('Muat ulang'), findsOneWidget);
      final btn = _button(tester, 'Absen Masuk');
      expect(btn.onPressed, isNull);
    });

    testWidgets('sedang bekerja: telat terlihat, ada izin keluar dan absen pulang', (tester) async {
      await tester.pumpWidget(_page(
        _day(shifts: [_shift(status: 'checked_in', attendanceId: 40)], atts: [_att()], open: 40),
        onDuty: const [
          OnDutyModel(attendanceId: 40, userId: 6, userName: 'Citra'),
          OnDutyModel(attendanceId: 41, userId: 7, userName: 'Dewi'),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Telat 5 menit'), findsOneWidget);
      expect(find.text('Izin keluar sebentar'), findsOneWidget);
      expect(find.text('Absen Pulang'), findsOneWidget);

      await tester.tap(find.text('Izin keluar sebentar'));
      await tester.pumpAndSettle();
      // Rekan serah tugas: yang bertugas di outlet ini, tanpa dirinya.
      await tester.tap(find.text('Tanpa serah tugas'));
      await tester.pumpAndSettle();
      expect(find.text('Dewi'), findsWidgets);
      expect(find.text('Citra'), findsNothing);
    });

    testWidgets('sedang izin keluar: tombol kembali', (tester) async {
      await tester.pumpWidget(_page(
        _day(shifts: [_shift(status: 'checked_in', attendanceId: 40)], atts: [_att()], open: 40),
        onDuty: const [OnDutyModel(attendanceId: 40, userId: 6, userName: 'Citra', leaveOutId: 9)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Saya sudah kembali'), findsOneWidget);
      expect(find.text('Izin keluar sebentar'), findsNothing);
    });

    testWidgets('di antara dua shift: shift 1 selesai, shift 2 menunggu dibuka', (tester) async {
      await tester.pumpWidget(_page(_day(
        shifts: [
          _shift(status: 'done', attendanceId: 40),
          _shift(id: 32, name: 'Shift 2', start: '15:00', end: '23:00', status: 'upcoming', branch: 1),
        ],
        atts: [_att(out: true)],
        next: true,
        now: '2026-11-03T15:05:00+07:00',
      )));
      await tester.pumpAndSettle();
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Pusat'), findsOneWidget);
      expect(find.textContaining('Absen masuk Shift 2 dibuka jam 14.40'), findsNothing);
      // Jam server 15.05 sudah lewat 14.40: dinilai terbuka di HP.
      expect(find.textContaining('Absen masuk Shift 2 di Pusat'), findsOneWidget);
    });

    testWidgets('selesai semua: absensi lengkap', (tester) async {
      await tester.pumpWidget(_page(_day(shifts: [_shift(status: 'done', attendanceId: 40)], atts: [_att(out: true)])));
      await tester.pumpAndSettle();
      expect(find.textContaining('Absensi hari ini sudah lengkap'), findsOneWidget);
    });
  });

  group('halaman baru', () {
    Widget host(Widget page, {AuthState? auth, List<Override> extra = const []}) => ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FixedAuth(auth ?? _auth(['leader']))),
            branchListProvider.overrideWith((ref) async => const []),
            ...extra,
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: page),
        );

    testWidgets('Jadwal Saya: hari ini ditandai, Libur tanpa jam', (tester) async {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final besok = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
      await tester.pumpWidget(host(const MySchedulePage(), extra: [
        mySchedulesProvider.overrideWith((ref) async => [
              MyScheduleEntry.fromJson({
                'id': 1,
                'date': today,
                'duty': 'both',
                'shift_code': _code(1, 'Shift 1', '07:00', '15:00'),
                'location': {'type': 'branch', 'id': 2, 'name': 'Karangampel'},
              }),
              MyScheduleEntry.fromJson({
                'id': 2,
                'date': besok,
                'shift_code': {'id': 4, 'name': 'Libur', 'kind': 'off_day'},
                'location': {'type': 'branch', 'id': 2, 'name': 'Karangampel'},
              }),
            ]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Hari ini'), findsOneWidget);
      expect(find.text('Shift 1 · Kasir & penyaji · 07.00–15.00'), findsOneWidget);
      expect(find.text('Libur'), findsOneWidget);
    });

    testWidgets('Yang Bertugas: leader menandai lembur', (tester) async {
      await tester.pumpWidget(host(const OnDutyPage(), extra: [
        onDutyProvider.overrideWith((ref, _) async => const [
              OnDutyModel(attendanceId: 40, userId: 6, userName: 'Citra', lateMinutes: 5, shiftName: 'Shift 1', duty: 'cashier'),
              OnDutyModel(attendanceId: 41, userId: 7, userName: 'Dewi', shiftName: 'shift_2', overtime: true, leaveOutId: 3),
            ]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Citra'), findsOneWidget);
      expect(find.text('Telat 5 menit'), findsOneWidget);
      expect(find.text('Sedang izin keluar'), findsOneWidget);
      expect(find.text('Tandai lembur'), findsOneWidget);
      expect(find.text('Cabut lembur'), findsOneWidget);
    });

    testWidgets('Yang Bertugas: SPV tanpa cabang aktif diminta memilih cabang', (tester) async {
      await tester.pumpWidget(host(const OnDutyPage(), auth: _auth(['supervisor'], branchId: null)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pilih cabang aktif'), findsOneWidget);
    });

    testWidgets('Izin Keluar: riwayat dengan serah tugas dan tutup otomatis', (tester) async {
      await tester.pumpWidget(host(const LeaveOutListPage(), extra: [
        leaveOutsProvider.overrideWith((ref, _) async => [
              LeaveOutModel.fromJson({
                'id': 1, 'reason': 'beli es batu', 'user_name': 'Citra', 'handover_name': 'Dewi',
                'out_at': '2026-11-03T10:15:00+07:00', 'back_at': '2026-11-03T10:40:00+07:00', 'minutes': 25,
              }),
              LeaveOutModel.fromJson({
                'id': 2, 'reason': 'ambil galon', 'user_name': 'Citra',
                'out_at': '2026-11-03T13:00:00+07:00', 'back_at': '2026-11-03T15:02:00+07:00', 'back_auto': true,
              }),
            ]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('beli es batu'), findsOneWidget);
      expect(find.text('25 menit'), findsOneWidget);
      expect(find.textContaining('serah tugas ke Dewi'), findsOneWidget);
      expect(find.textContaining('ditutup saat absen pulang'), findsOneWidget);
    });

    testWidgets('Profil: data kerja hanya dibaca, Simpan menyala setelah diubah', (tester) async {
      await tester.pumpWidget(host(const ProfilePage(), extra: [
        myProfileProvider.overrideWith((ref) async => ProfileModel.fromJson({
              'id': 6, 'name': 'Citra', 'email': 'citra@t.local', 'roles': ['karyawan'],
              'phone': '0812', 'nik': '3201010101010001', 'bank_name': 'BCA', 'bank_account': '123',
              'joined_at': '2026-07-14',
            })),
      ]));
      await tester.pumpAndSettle();
      expect(_button(tester, 'Simpan').onPressed, isNull);
      await tester.enterText(find.widgetWithText(TextField, 'Nomor HP'), '0812-3456-7890');
      await tester.pump();
      expect(_button(tester, 'Simpan').onPressed, isNotNull);
      await tester.scrollUntilVisible(find.text('3201010101010001'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('14 Juli 2026'), findsOneWidget);
      // Bukan leader: tidak ada baris cabang (cabang utama dihapus 25 Okt).
      expect(find.text('Cabang utama'), findsNothing);
      expect(find.text('Cabang yang dipimpin'), findsNothing);
      await tester.scrollUntilVisible(find.text('Ganti password'), 200, scrollable: find.byType(Scrollable).first);
    });
  });

  test('profil leader membawa cabang yang dipimpin', () {
    final leader = ProfileModel.fromJson({
      'id': 4, 'name': 'Rina', 'roles': ['leader'],
      'lead_branch': {'id': 2, 'name': 'Karangampel'},
    });
    expect(leader.leadBranchName, 'Karangampel');
    final crew = ProfileModel.fromJson({'id': 6, 'name': 'Citra', 'lead_branch': null, 'primary_branch': {'id': 1, 'name': 'Pusat'}});
    expect(crew.leadBranchName, isNull, reason: 'primary_branch lama tidak dibaca lagi');
  });
}
