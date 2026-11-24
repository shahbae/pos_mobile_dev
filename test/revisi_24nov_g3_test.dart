import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/kpi_revisi_model.dart';
import 'package:pos_mobile/data/models/overtime_model.dart';
import 'package:pos_mobile/data/models/schedule_model.dart';
import 'package:pos_mobile/presentation/pages/schedules/my_schedule_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/widgets/live_session_card.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Revisi owner 24 Nov 2026, langkah 3 (app kasir): jam Live TikTok yang diatur
/// SPV tampil di Jadwal Saya dan di kartu Live Beranda. Hanya informasi; tombol
/// Mulai/Selesai dan penilaian KPI tidak berubah.

final _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

Map<String, dynamic> _entry({bool live = false, String? start, String? end}) => {
      'id': 7,
      'date': _today,
      'duty': 'cashier',
      'shift_code': {
        'id': 1,
        'name': 'Shift 1',
        'short_name': 'S1',
        'kind': 'work',
        'start_time': '07:00',
        'end_time': '15:00',
        'checkout_limit': null,
      },
      'location': {'type': 'branch', 'id': 2, 'name': 'Karangampel'},
      'live': live,
      'live_start': start,
      'live_end': end,
    };

Widget _app(Widget home, [List<Override> overrides = const []]) =>
    ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: home));

Future<void> _tablet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  group('MyScheduleEntry', () {
    test('Live dengan jam: label berisi jam, titik dua jadi titik', () {
      final e = MyScheduleEntry.fromJson(_entry(live: true, start: '19:00', end: '21:30'));
      expect(e.live, isTrue);
      expect(e.liveLabel, 'Live TikTok 19.00–21.30');
    });

    test('Live tanpa jam = seluruh shift', () {
      expect(MyScheduleEntry.fromJson(_entry(live: true)).liveLabel, 'Live TikTok');
      expect(MyScheduleEntry.fromJson(_entry(live: true, start: '19:00')).liveLabel, 'Live TikTok');
    });

    test('tidak dijadwalkan Live: tanpa label; server lama tanpa field juga aman', () {
      expect(MyScheduleEntry.fromJson(_entry()).liveLabel, isNull);
      final old = _entry()..remove('live')..remove('live_start')..remove('live_end');
      expect(MyScheduleEntry.fromJson(old).liveLabel, isNull);
    });
  });

  group('Jadwal Saya', () {
    List<Override> over(Map<String, dynamic> entry) => [
          mySchedulesProvider.overrideWith((ref) async => [MyScheduleEntry.fromJson(entry)]),
          myOvertimesProvider.overrideWith((ref) async => const <ScheduledOvertime>[]),
        ];

    testWidgets('baris Live dengan jam tampil di bawah lokasi', (tester) async {
      await _tablet(tester);
      await tester.pumpWidget(_app(const MySchedulePage(), over(_entry(live: true, start: '19:00', end: '21:00'))));
      await tester.pumpAndSettle();
      expect(find.text('Live TikTok 19.00–21.00'), findsOneWidget);
    });

    testWidgets('tanpa Live: tidak ada baris Live', (tester) async {
      await _tablet(tester);
      await tester.pumpWidget(_app(const MySchedulePage(), over(_entry())));
      await tester.pumpAndSettle();
      expect(find.textContaining('Live TikTok'), findsNothing);
    });
  });

  group('Kartu Live di Beranda', () {
    Map<String, dynamic> slot({String? start, String? end}) => {
          'schedule_id': 1,
          'shift_name': 'Shift 2',
          'shift_start': '2026-11-14T15:00:00+07:00',
          'shift_end': '2026-11-14T23:00:00+07:00',
          'live_start': start,
          'live_end': end,
          'can_start': true,
        };

    Widget tile(LiveSlot s) => _app(Scaffold(
          body: LiveSlotTile(slot: s, onStart: () {}, onFinish: () {}, onScreenshot: () {}),
        ));

    testWidgets('jam live dari SPV tampil sebagai jadwal live', (tester) async {
      await _tablet(tester);
      await tester.pumpWidget(tile(LiveSlot.fromJson(slot(start: '19:00', end: '21:00'))));
      expect(find.text('Jadwal live: 19.00–21.00 (diatur SPV).'), findsOneWidget);
      // Tombol dan aturan lama tidak berubah.
      expect(find.textContaining('minimal 60 menit'), findsOneWidget);
    });

    testWidgets('tanpa jam: tidak ada baris jadwal live', (tester) async {
      await _tablet(tester);
      await tester.pumpWidget(tile(LiveSlot.fromJson(slot())));
      expect(find.textContaining('Jadwal live:'), findsNothing);
    });
  });
}
