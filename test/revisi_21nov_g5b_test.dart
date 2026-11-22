import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/overtime_model.dart';
import 'package:pos_mobile/data/repositories/attendance_repository.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/presentation/pages/attendance/overtime_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Revisi owner 21 Nov 2026, fase 5b: lembur terjadwal. Masuk ulang (selfie +
/// GPS) dan pulang lembur dari app; tanda lembur manual dicabut. JSON dari
/// be-pos `feat/revisi-21nov-g5b`.

class _Adapter implements HttpClientAdapter {
  RequestOptions? last;
  String? lastBody;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    if (requestStream != null) {
      final bytes = await requestStream.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      lastBody = latin1.decode(bytes);
    }
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': _json(status: 'active')}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

final _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

Map<String, dynamic> _json({int id = 5, String status = 'scheduled', bool cross = true, int hours = 0}) => {
      'id': id,
      'user_id': 42,
      'user_name': 'Crew',
      'date': _today,
      'home': {'type': 'branch', 'id': 12, 'name': 'JUNTIKEBON'},
      'location': {'type': 'branch', 'id': 7, 'name': 'KARANGAMPEL'},
      'cross_location': cross,
      'start_time': '15:30',
      'end_time': '19:00',
      'note': 'Bantu sore ramai',
      'status': status,
      'check_in_at': status == 'scheduled' ? null : '${_today}T15:32:00+07:00',
      'check_out_at': status == 'completed' ? '${_today}T19:03:00+07:00' : null,
      'minutes': status == 'completed' ? 208 : null,
      'hours': hours,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  group('permintaan ke server', () {
    test('masuk ulang: multipart photo + latitude + longitude ke /me/overtimes/:id/check-in', () async {
      final adapter = _Adapter();
      final api = ApiService()..dio.httpClientAdapter = adapter;
      final photo = File('${Directory.systemTemp.path}/selfie-lembur-uji.jpg')..writeAsBytesSync(List.filled(64, 1));
      final ot = await AttendanceRepository(api).overtimeCheckIn(id: 5, photoPath: photo.path, latitude: -6.46, longitude: 108.45);
      expect(adapter.last!.path, '/me/overtimes/5/check-in');
      expect(adapter.lastBody, contains('name="photo"'));
      expect(adapter.lastBody, contains('name="latitude"'));
      expect(ot.isActive, isTrue);
    });

    test('pulang lembur: JSON ke /me/overtimes/:id/check-out', () async {
      final adapter = _Adapter();
      final api = ApiService()..dio.httpClientAdapter = adapter;
      await AttendanceRepository(api).overtimeCheckOut(id: 5, latitude: -6.46, longitude: 108.45);
      expect(adapter.last!.path, '/me/overtimes/5/check-out');
      expect(adapter.last!.method, 'POST');
    });

    test('model: lintas cabang, jam, status', () {
      final ot = ScheduledOvertime.fromJson(_json(status: 'completed', hours: 3));
      expect(ot.crossLocation, isTrue);
      expect(ot.hoursLabel, '15.30–19.00');
      expect(ot.statusLabel, 'Selesai');
      expect(ot.hours, 3);
      expect(ot.location.name, 'KARANGAMPEL');
    });
  });

  group('layar (360 × 800 dp, tema app)', () {
    Future<void> pump(WidgetTester tester, Widget page, List<ScheduledOvertime> rows) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Kunci baru tiap pompa: ProviderScope lama tidak menerima override baru.
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [myOvertimesProvider.overrideWith((ref) async => rows)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: page)),
      ));
      await tester.pumpAndSettle();
    }

    Finder btn(String text) =>
        find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

    testWidgets('Absen Lembur: terjadwal → Masuk ulang; aktif → Pulang; selesai → jam dibayar', (tester) async {
      await pump(tester, const OvertimePage(), [
        ScheduledOvertime.fromJson(_json(id: 1)),
        ScheduledOvertime.fromJson(_json(id: 2, status: 'active', cross: false)),
        ScheduledOvertime.fromJson(_json(id: 3, status: 'completed', hours: 3)),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Di KARANGAMPEL (bantuan dari JUNTIKEBON)'), findsWidgets);
      expect(btn('Masuk ulang lembur'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(btn('Masuk ulang lembur')).onPressed, isNotNull);
      await tester.scrollUntilVisible(btn('Pulang lembur'), 200,
          scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
      expect(btn('Pulang lembur'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('3 jam dibayar'), 200,
          scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
      expect(find.textContaining('3 jam dibayar'), findsOneWidget);
    });

    testWidgets('Absen Lembur kosong: pesan', (tester) async {
      await pump(tester, const OvertimePage(), const []);
      expect(find.text('Tidak ada jadwal lembur hari ini dan seminggu ke depan.'), findsOneWidget);
    });

    testWidgets('Kartu di layar Absensi: tampil bila ada lembur belum selesai, hilang bila semua selesai', (tester) async {
      await pump(tester, const OvertimeEntryCard(), [ScheduledOvertime.fromJson(_json())]);
      expect(find.text('Ada jadwal lembur'), findsOneWidget);
      expect(find.text('15.30–19.00 di KARANGAMPEL'), findsOneWidget);
      expect(find.text('Absen Lembur'), findsOneWidget);
      await pump(tester, const OvertimeEntryCard(), [ScheduledOvertime.fromJson(_json(status: 'completed', hours: 3))]);
      expect(find.text('Absen Lembur'), findsNothing);
    });
  });
}
