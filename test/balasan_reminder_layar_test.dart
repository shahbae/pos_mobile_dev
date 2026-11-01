import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/data/models/reminder_model.dart';
import 'package:pos_mobile/data/repositories/reminder_repository.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_detail_page.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Layar balas pengecekan foto di HP (uji 1 Nov 2026): nama bagian tampil
/// satu huruf per baris dan tombol Foto hilang, karena tombol bertema lebar
/// penuh diletakkan sebaris dengan teks.
class _Repo implements ReminderRepository {
  _Repo(this.r);
  final MyReminder r;

  static final _empty = MyReminderPage.fromJson({'items': [], 'total': 0, 'page': 1, 'limit': 20});

  @override
  Future<MyReminder> open(int id) async => r;
  @override
  Future<MyReminder> one(int id) async => r;
  @override
  Future<MyReminderPage> pending() async => _empty;
  @override
  Future<MyReminderPage> history({int page = 1, int limit = 30}) async => _empty;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

MyReminder _check({required Duration left, bool judged = false}) {
  final now = DateTime.now().toUtc();
  return MyReminder.fromJson({
    'id': 7,
    'kind': 'check',
    'message': '',
    'sender_name': 'Admin',
    'created_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
    'branch_id': 2,
    'branch_name': 'JUNTIKEBON',
    'duty': 'server',
    'status': left > Duration.zero ? 'pending' : 'missed',
    'deadline_minutes': 5,
    'deadline_at': now.add(left).toIso8601String(),
    'parts': [
      {'id': 1, 'name': 'Lantai area dalam', 'duty': 'server', 'photo': null},
      {
        'id': 2,
        'name': 'Meja penyaji dan rak cup di depan etalase',
        'duty': 'server',
        'photo': {
          'id': 9,
          'url': 'https://x.invalid/uploads/a.jpg',
          'received_at': now.toIso8601String(),
          'verdict': judged ? 'clean' : null,
        },
      },
    ],
    'server_time': now.toIso8601String(),
  });
}

Future<void> _pump(WidgetTester tester, MyReminder r) async {
  // HP 360 × 800 dp, sama dengan layar di tangkapan uji.
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(_Repo(r))],
      // Tema app wajib ikut: lebar minimum tombolnya yang memicu bug.
      child: MaterialApp(theme: AppTheme.lightTheme, home: const ReminderDetailPage(reminderId: 7)),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Tombol `.icon` adalah subkelas privat, jadi dicari dengan `is`, bukan tipe persis.
Finder _button<T extends ButtonStyleButton>(String text) =>
    find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is T));

Finder _anyButton<T extends ButtonStyleButton>() => find.byWidgetPredicate((w) => w is T);

Future<void> _close(WidgetTester tester) async {
  // Hitung mundur berhenti saat layar ditutup.
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    // Layar ini mematikan alarm saat dibuka (cancelTag). Di HP plugin
    // notifikasi terdaftar otomatis; di tes didaftarkan di sini dan kanalnya
    // dijawab kosong.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => null,
    );
  });

  testWidgets('nama bagian satu baris, tombol foto terlihat selebar kartu', (tester) async {
    await _pump(tester, _check(left: const Duration(minutes: 4)));
    expect(tester.takeException(), isNull);

    // Kolom nama memakai sisa lebar kartu, bukan tergencet selebar satu huruf.
    expect(tester.getRect(find.text('Lantai area dalam')).width, greaterThan(150));

    final shoot = _button<ElevatedButton>('Ambil foto');
    expect(shoot, findsOneWidget);
    final rect = tester.getRect(shoot);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(360));
    expect(rect.width, greaterThan(250), reason: 'tombol besar, mudah diketuk saat dikejar waktu');
    expect(tester.widget<ElevatedButton>(shoot).onPressed, isNotNull);

    // Bagian yang sudah terkirim tetap bisa diulang selama belum dinilai.
    final again = _button<OutlinedButton>('Foto ulang');
    expect(again, findsOneWidget);
    expect(tester.getRect(again).width, greaterThan(250));
    await _close(tester);
  });

  testWidgets('sudah dinilai: tidak bisa diulang', (tester) async {
    await _pump(tester, _check(left: const Duration(minutes: 4), judged: true));
    expect(tester.takeException(), isNull);
    expect(_button<ElevatedButton>('Ambil foto'), findsOneWidget);
    expect(find.text('Foto ulang'), findsNothing);
    await _close(tester);
  });

  testWidgets('waktu habis: tanpa tombol, nama bagian tetap rapi', (tester) async {
    await _pump(tester, _check(left: const Duration(minutes: -1)));
    expect(tester.takeException(), isNull);
    expect(_anyButton<ElevatedButton>(), findsNothing);
    expect(_anyButton<OutlinedButton>(), findsNothing);
    expect(tester.getRect(find.text('Lantai area dalam')).width, greaterThan(150));
    await _close(tester);
  });
}
