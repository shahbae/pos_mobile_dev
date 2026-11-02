import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/leave_out_model.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/data/models/reminder_model.dart';
import 'package:pos_mobile/data/repositories/reminder_repository.dart';
import 'package:pos_mobile/data/services/push_service.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_detail_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/presentation/providers/reminder_block.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';
import 'package:pos_mobile/presentation/widgets/pending_reminder_banner.dart';
import 'package:pos_mobile/presentation/widgets/push_binder.dart';
import 'package:pos_mobile/presentation/widgets/reminder_gate.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Layar blok reminder (uji manual 2 Nov 2026): reminder menutup seluruh app
/// sampai diselesaikan, tanpa merusak pembayaran yang sedang berjalan.

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Offline extends StateNotifier<OfflineState> implements OfflineNotifier {
  _Offline() : super(const OfflineState());

  // ignore: use_setters_to_change_properties
  void reachable(bool on) => state = OfflineState(reachable: on);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late DateTime clock;

Map<String, dynamic> _check(int id, {Duration left = const Duration(minutes: 15), String status = 'pending'}) => {
      'id': id,
      'kind': 'check',
      'message': 'Cek sebelum ramai sore.',
      'sender_name': 'Alena',
      'created_at': clock.toUtc().toIso8601String(),
      'branch_name': 'Karangampel',
      'status': status,
      'deadline_minutes': 15,
      'deadline_at': clock.add(left).toUtc().toIso8601String(),
      'parts': [
        {'id': 1, 'name': 'Meja kasir', 'duty': 'cashier', 'photo': null},
      ],
    };

Map<String, dynamic> _note(int id, {Duration age = Duration.zero, String status = 'pending'}) => {
      'id': id,
      'kind': 'note',
      'message': 'Stok cup tipis, hemat ya.',
      'sender_name': 'Khaerudien',
      'created_at': clock.subtract(age).toUtc().toIso8601String(),
      'branch_name': 'Karangampel',
      'status': status,
      'parts': const [],
    };

class _Repo implements ReminderRepository {
  List<Map<String, dynamic>> rows = [];
  bool failing = false;
  int pendingCalls = 0;
  int openCalls = 0;
  int readCalls = 0;

  MyReminderPage _page() => MyReminderPage.fromJson({
        'server_time': clock.toUtc().toIso8601String(),
        'items': rows,
        'total': rows.length,
      }, receivedAt: clock);

  @override
  Future<MyReminderPage> pending() async {
    pendingCalls++;
    if (failing) throw 'jaringan putus';
    return _page();
  }

  @override
  Future<MyReminderPage> history({int page = 1, int limit = 30}) async => _page();

  MyReminder _one(int id) => MyReminder.fromJson(
        rows.firstWhere((r) => r['id'] == id),
        serverTime: clock,
      );

  @override
  Future<MyReminder> one(int id) async => _one(id);

  @override
  Future<MyReminder> open(int id) async {
    openCalls++;
    return _one(id);
  }

  @override
  Future<MyReminder> markRead(int id) async {
    readCalls++;
    final read = _one(id);
    rows = rows.where((r) => r['id'] != id).toList();
    return read;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Beranda dengan pita, dan tombol menuju halaman lain.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Beranda')),
        body: Column(
          children: [
            const PendingReminderBanner(),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _Cart())),
              child: const Text('Transaksi'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _Payment())),
              child: const Text('Checkout'),
            ),
          ],
        ),
      );
}

/// Halaman biasa dengan isian yang harus tetap utuh di belakang blok.
class _Cart extends StatefulWidget {
  const _Cart();

  @override
  State<_Cart> createState() => _CartState();
}

class _CartState extends State<_Cart> {
  int items = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Keranjang')),
        body: Column(
          children: [
            Text('Isi $items'),
            ElevatedButton(onPressed: () => setState(() => items++), child: const Text('Tambah')),
          ],
        ),
      );
}

/// Berperilaku seperti Checkout dan QRIS.
class _Payment extends StatefulWidget {
  const _Payment();

  @override
  State<_Payment> createState() => _PaymentState();
}

class _PaymentState extends State<_Payment> with ReminderPaymentHold {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bayar')),
        body: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Lunas')),
      );
}

class _Scene {
  _Scene(this.repo, this.offline, this.tester);
  final _Repo repo;
  final _Offline offline;
  final WidgetTester tester;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(ReminderGate)));

  /// Sama dengan tarikan berkala atau notifikasi yang masuk.
  Future<void> refresh() async {
    container.invalidate(pendingRemindersProvider);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  Future<void> open(String button) async {
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
  }
}

Finder get _layer => find.byWidgetPredicate((w) => w is ReminderDetailPage && w.blocking);

final _cancelled = <String>[];

Future<_Scene> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>> rows = const [],
  List<String> roles = const ['karyawan'],
  MyDay? day,
  List<OnDutyModel> onDuty = const [],
  bool binder = false,
}) async {
  // HP 360 × 800 dp.
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final repo = _Repo()..rows = rows;
  final offline = _Offline();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => _FixedAuth(AuthState(status: AuthStatus.authenticated, role: roles.first, roles: roles)),
        ),
        reminderRepositoryProvider.overrideWithValue(repo),
        offlineProvider.overrideWith((ref) => offline),
        myDayProvider.overrideWith((ref) async => day ?? MyDay.fromToday(null)),
        onDutyProvider.overrideWith((ref, _) async => onDuty),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (_, child) => ReminderGate(now: () => clock, child: child!),
        home: binder ? const PushBinder(child: _Home()) : const _Home(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return _Scene(repo, offline, tester);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        if (call.method == 'cancel') _cancelled.add('${(call.arguments as Map)['tag']}');
        return null;
      },
    );
    // Kamera dibatalkan orangnya: cukup untuk menguji tombol pertama.
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      (_) async => null,
    );
  });

  setUp(() {
    clock = DateTime.now();
    _cancelled.clear();
    ReminderHold.count.value = 0;
  });

  group('aturan', () {
    MyReminderPage page(List<Map<String, dynamic>> rows, {DateTime? server}) => MyReminderPage.fromJson(
          {'server_time': (server ?? clock).toUtc().toIso8601String(), 'items': rows, 'total': rows.length},
          receivedAt: clock,
        );

    test('pengecekan lebih dulu menurut tenggat, lalu catatan terlama', () {
      final list = remindersToBlock(
        page([
          _note(1),
          _note(2, age: const Duration(hours: 2)),
          _check(3, left: const Duration(minutes: 9)),
          _check(4, left: const Duration(minutes: 2)),
        ]),
        clock,
      );
      expect(list.map((r) => r.id), [4, 3, 2, 1]);
    });

    test('tenggat habis gugur tanpa menunggu jawaban server', () {
      final p = page([_check(1, left: const Duration(minutes: 5))]);
      expect(remindersToBlock(p, clock.add(const Duration(minutes: 4))), hasLength(1));
      expect(remindersToBlock(p, clock.add(const Duration(minutes: 5))), isEmpty);
    });

    test('sisa waktu mengikuti jam server walau jam HP meleset sejam', () {
      final server = clock.add(const Duration(hours: 1));
      final deadline = {
        ..._check(1),
        'deadline_at': server.add(const Duration(minutes: 5)).toUtc().toIso8601String(),
      };
      final p = page([deadline], server: server);
      final r = p.items.single;
      expect(reminderTimeLeft(r, p, clock)!.inMinutes, 5);
      expect(remindersToBlock(p, clock), hasLength(1));
    });

    test('pengecekan tanpa tenggat dan yang sudah selesai tidak memblok', () {
      expect(
        remindersToBlock(
          page([
            {..._check(1), 'deadline_at': null},
            _check(2, status: 'replied'),
            _note(3, status: 'read'),
          ]),
          clock,
        ),
        isEmpty,
      );
    });

    test('id reminder dari tujuan ketukan', () {
      expect(reminderIdOfTarget('app:/reminders/12'), 12);
      expect(reminderIdOfTarget('app:/help-tickets/5'), isNull);
      expect(reminderIdOfTarget('web:/reminders/12'), isNull);
      expect(reminderIdOfTarget('app:/reminders'), isNull);
    });
  });

  group('blok', () {
    testWidgets('menutup halaman mana pun; halaman di belakang tidak bisa ditekan', (tester) async {
      final s = await _pump(tester);
      await s.open('Transaksi');
      expect(_layer, findsNothing);

      s.repo.rows = [_check(7)];
      await s.refresh();
      expect(tester.takeException(), isNull);
      expect(_layer, findsOneWidget);
      expect(find.text('Pengecekan Foto'), findsOneWidget);
      expect(find.text('Selesaikan ini dulu untuk kembali ke aplikasi.'), findsOneWidget);
      expect(find.descendant(of: _layer, matching: find.byType(BackButton)), findsNothing);

      final shoot = find.ancestor(of: find.text('Ambil foto'), matching: find.byWidgetPredicate((w) => w is ElevatedButton));
      expect(shoot, findsOneWidget);
      expect(tester.getRect(shoot).width, greaterThan(250));

      await tester.tap(find.text('Tambah'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('Isi 0', skipOffstage: false), findsOneWidget);
      await _close(tester);
    });

    testWidgets('halaman di belakang yang menutup diri tidak menutup blok (kasus QRIS lunas)', (tester) async {
      final s = await _pump(tester);
      final done = <Object?>[];
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<String>(builder: (_) => const _Cart())).then(done.add);
      await tester.pumpAndSettle();

      s.repo.rows = [_check(7)];
      await s.refresh();
      expect(_layer, findsOneWidget);

      nav.pop('INV-1');
      await tester.pumpAndSettle();
      expect(done, ['INV-1'], reason: 'hasil sampai ke pemanggilnya');
      expect(_layer, findsOneWidget, reason: 'blok tidak ikut tertutup');
      expect(find.text('Keranjang', skipOffstage: false), findsNothing);
      await _close(tester);
    });

    testWidgets('pushReplacement di belakang tidak menggantikan blok', (tester) async {
      final s = await _pump(tester);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<void>(builder: (_) => const _Cart()));
      await tester.pumpAndSettle();
      s.repo.rows = [_check(7)];
      await s.refresh();

      nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Berhasil'))));
      await tester.pumpAndSettle();
      expect(_layer, findsOneWidget);
      expect(find.text('Berhasil', skipOffstage: false), findsOneWidget);
      await _close(tester);
    });

    testWidgets('tombol Back ditahan selama blok, lalu normal lagi', (tester) async {
      WidgetsBinding.instance.addObserver(ReminderBackGuard.instance);
      addTearDown(() => WidgetsBinding.instance.removeObserver(ReminderBackGuard.instance));
      final s = await _pump(tester);
      await s.open('Transaksi');
      s.repo.rows = [_note(1)];
      await s.refresh();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Keranjang', skipOffstage: false), findsOneWidget, reason: 'halaman belakang tetap ada');
      expect(_layer, findsOneWidget);

      await s.open('Sudah dibaca');
      expect(_layer, findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Keranjang', skipOffstage: false), findsNothing);
      await _close(tester);
    });

    testWidgets('isi halaman di belakang utuh sesudah blok selesai', (tester) async {
      final s = await _pump(tester);
      await s.open('Transaksi');
      await s.open('Tambah');
      expect(find.text('Isi 1'), findsOneWidget);

      s.repo.rows = [_note(1)];
      await s.refresh();
      await s.open('Sudah dibaca');
      expect(_layer, findsNothing);
      expect(find.text('Isi 1'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('satu per satu; yang sedang tampil tidak direbut kiriman baru', (tester) async {
      final s = await _pump(tester, rows: [_note(1)]);
      expect(find.text('Catatan'), findsOneWidget);

      s.repo.rows = [_note(1), _check(2)];
      await s.refresh();
      expect(find.text('Catatan'), findsOneWidget);

      await s.open('Sudah dibaca');
      expect(find.text('Pengecekan Foto'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('SPV dan owner tidak menarik daftar dan tidak pernah diblok', (tester) async {
      final s = await _pump(tester, roles: ['supervisor'], rows: [_check(7)]);
      expect(s.repo.pendingCalls, 0);
      expect(_layer, findsNothing);
      await _close(tester);
    });

  });

  group('alarm dan jam dibuka', () {
    testWidgets('tampil sendiri: alarm tetap berbunyi, belum tercatat dibuka', (tester) async {
      final s = await _pump(tester, rows: [_check(7)]);
      expect(_layer, findsOneWidget);
      expect(s.repo.openCalls, 0);
      expect(_cancelled, isEmpty);

      await tester.tap(find.text('Ambil foto'));
      await tester.pump();
      await tester.pump();
      expect(s.repo.openCalls, 1);
      expect(_cancelled, ['reminder-7']);

      await tester.tap(find.text('Ambil foto'));
      await tester.pump();
      await tester.pump();
      expect(s.repo.openCalls, 1, reason: 'hanya tombol pertama');
      await _close(tester);
    });

    testWidgets('dibuka dari daftar (bukan blok): perilaku lama tetap', (tester) async {
      final repo = _Repo()..rows = [_check(7)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(theme: AppTheme.lightTheme, home: const ReminderDetailPage(reminderId: 7)),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(repo.openCalls, 1);
      expect(_cancelled, ['reminder-7']);
      await _close(tester);
    });
  });

  group('pembayaran menahan blok', () {
    testWidgets('blok menunggu halaman pembayaran ditutup', (tester) async {
      final s = await _pump(tester);
      await s.open('Checkout');
      s.repo.rows = [_check(7)];
      await s.refresh();
      expect(_layer, findsNothing);
      expect(find.text('Lunas'), findsOneWidget);

      await s.open('Lunas');
      expect(tester.takeException(), isNull);
      expect(_layer, findsOneWidget);
      await _close(tester);
    });

    testWidgets('berpindah dari Checkout ke QRIS ke Berhasil tetap tertahan', (tester) async {
      final s = await _pump(tester, rows: const []);
      await s.open('Checkout');
      s.repo.rows = [_check(7)];
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<void>(builder: (_) => const _Payment()));
      await tester.pumpAndSettle();
      await s.refresh();
      expect(_layer, findsNothing);

      nav.pop();
      await tester.pumpAndSettle();
      expect(_layer, findsNothing, reason: 'Checkout masih terbuka');

      nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => const _Payment()));
      await tester.pumpAndSettle();
      expect(_layer, findsNothing, reason: 'halaman Berhasil masih terbuka');

      nav.pop();
      await tester.pumpAndSettle();
      expect(_layer, findsOneWidget);
      await _close(tester);
    });

    testWidgets('tenggat habis selama pembayaran: blok batal, alarm berhenti', (tester) async {
      final s = await _pump(tester);
      await s.open('Checkout');
      s.repo.rows = [_check(7, left: const Duration(minutes: 5))];
      await s.refresh();
      expect(_cancelled, isEmpty);

      clock = clock.add(const Duration(minutes: 6));
      await tester.pump(const Duration(minutes: 6));
      expect(_cancelled, ['reminder-7']);

      await s.open('Lunas');
      expect(_layer, findsNothing);
      await _close(tester);
    });
  });

  group('blok tidak boleh menjebak', () {
    testWidgets('tenggat habis lewat jam HP, walau server tak menjawab', (tester) async {
      await _pump(tester, rows: [_check(7, left: const Duration(minutes: 5))]);
      expect(_layer, findsOneWidget);

      clock = clock.add(const Duration(minutes: 6));
      await tester.pump(const Duration(minutes: 6));
      expect(_layer, findsNothing);
      expect(_cancelled, contains('reminder-7'));
      await _close(tester);
    });

    testWidgets('sinyal putus: blok lepas, pita tetap, blok kembali saat tersambung', (tester) async {
      final s = await _pump(tester, rows: [_check(7)]);
      expect(_layer, findsOneWidget);

      s.offline.reachable(false);
      await tester.pump();
      expect(_layer, findsNothing);
      expect(find.text('1 permintaan foto menunggu'), findsOneWidget);

      s.offline.reachable(true);
      await tester.pump();
      expect(_layer, findsOneWidget);
      await _close(tester);
    });

    testWidgets('tarikan gagal (server mati, APK ditolak 426): blok lepas', (tester) async {
      final s = await _pump(tester, rows: [_check(7)]);
      expect(_layer, findsOneWidget);

      s.repo.failing = true;
      await s.refresh();
      expect(_layer, findsNothing);

      s.repo.failing = false;
      await s.refresh();
      expect(_layer, findsOneWidget);
      await _close(tester);
    });

    testWidgets('sedang izin keluar: hanya pita', (tester) async {
      final att = AttendanceModel.fromJson({'id': 5, 'branch_id': 2, 'check_in_at': clock.toUtc().toIso8601String()});
      await _pump(
        tester,
        day: MyDay(date: '2026-11-02', shifts: const [], attendances: [att], openAttendanceId: 5),
        onDuty: const [OnDutyModel(attendanceId: 5, userId: 1, userName: 'Crew', leaveOutId: 3)],
        rows: [_check(7)],
      );
      await tester.pump();
      await tester.pump();
      expect(_layer, findsNothing);
      expect(find.text('1 permintaan foto menunggu'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('sudah kembali dari izin keluar: diblok seperti biasa', (tester) async {
      final att = AttendanceModel.fromJson({'id': 5, 'branch_id': 2, 'check_in_at': clock.toUtc().toIso8601String()});
      await _pump(
        tester,
        day: MyDay(date: '2026-11-02', shifts: const [], attendances: [att], openAttendanceId: 5),
        onDuty: const [OnDutyModel(attendanceId: 5, userId: 1, userName: 'Crew')],
        rows: [_check(7)],
      );
      await tester.pump();
      expect(_layer, findsOneWidget);
      await _close(tester);
    });
  });

  group('sambungan notifikasi', () {
    testWidgets('daftar ditarik tiap 60 detik selama app di depan', (tester) async {
      final s = await _pump(tester, binder: true);
      final before = s.repo.pendingCalls;

      s.repo.rows = [_check(7)];
      await tester.pump(reminderPollInterval);
      await tester.pump();
      await tester.pump();
      expect(s.repo.pendingCalls, greaterThan(before));
      expect(_layer, findsOneWidget);
      await _close(tester);
    });

    testWidgets('notifikasi diketuk saat blok tampil: tidak membuka layar kedua', (tester) async {
      final s = await _pump(tester, binder: true, rows: [_check(7)]);
      expect(_layer, findsOneWidget);

      PushService.pendingTarget.value = 'app:/reminders/7';
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(ReminderDetailPage, skipOffstage: false), findsOneWidget);
      expect(s.repo.openCalls, 0);
      await _close(tester);
    });

    testWidgets('notifikasi diketuk saat pembayaran: menunggu, lalu dibuka', (tester) async {
      final s = await _pump(tester, binder: true, rows: [_check(7, status: 'missed')]);
      await s.open('Checkout');

      PushService.pendingTarget.value = 'app:/reminders/7';
      await tester.pump();
      await tester.pump();
      expect(find.byType(ReminderDetailPage, skipOffstage: false), findsNothing);
      expect(PushService.pendingTarget.value, isNotNull);

      await s.open('Lunas');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(PushService.pendingTarget.value, isNull);
      expect(find.byType(ReminderDetailPage), findsOneWidget, reason: 'tenggat lewat: halaman biasa');
      expect(_layer, findsNothing);
      await _close(tester);
    });
  });
}
