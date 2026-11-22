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

import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/models/schedule_model.dart';
import 'package:pos_mobile/data/repositories/attendance_repository.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/presentation/pages/schedules/my_schedule_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Revisi owner 21 Nov 2026, fase 5a: SPV kerja harian di gudang (absen lewat
/// jalur gudang), Jadwal SPV Keliling khusus sidak. Bentuk JSON dari be-pos
/// `feat/revisi-21nov-g5a`.

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
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'id': 7, 'user_id': 2, 'check_in_at': '2026-11-22T06:45:00+07:00', 'warehouse_id': 1},
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

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

  group('absen SPV di gudang', () {
    late File photo;
    setUp(() async {
      photo = File('${Directory.systemTemp.path}/selfie-uji-g5a.jpg')..writeAsBytesSync(List.filled(64, 1));
    });

    test('ada warehouseId: lewat jalur gudang, kirim warehouse_id tanpa branch_id', () async {
      final adapter = _Adapter();
      final api = ApiService()..dio.httpClientAdapter = adapter;
      await AttendanceRepository(api).checkIn(
        photoPath: photo.path,
        branchId: 12,
        warehouseId: 1,
        latitude: -6.43,
        longitude: 108.43,
      );
      expect(adapter.last!.path, '/attendance/warehouse/check-in');
      expect(adapter.lastBody, contains('name="warehouse_id"'));
      expect(adapter.lastBody, isNot(contains('name="branch_id"')));
    });

    test('tanpa warehouseId: jalur outlet seperti dulu', () async {
      final adapter = _Adapter();
      final api = ApiService()..dio.httpClientAdapter = adapter;
      await AttendanceRepository(api).checkIn(photoPath: photo.path, branchId: 12, latitude: -6.43, longitude: 108.43);
      expect(adapter.last!.path, '/attendance/check-in');
      expect(adapter.lastBody, contains('name="branch_id"'));
    });
  });

  group('jadwal sidak', () {
    test('baris jadwal saya membawa outlet sidak', () {
      final e = MyScheduleEntry.fromJson({
        'id': 2434,
        'date': '2026-11-22',
        'shift_code': {'id': 1, 'name': 'Shift 1', 'short_name': 'S1', 'kind': 'work', 'start_time': '07:00', 'end_time': '15:00'},
        'location': {'type': 'roving', 'id': 0, 'name': 'SPV keliling'},
        'inspection_branch': {'type': 'branch', 'id': 12, 'name': 'JUNTIKEBON'},
      });
      expect(e.isSidak, isTrue);
      expect(e.inspectionBranch!.name, 'JUNTIKEBON');
      final g = MyScheduleEntry.fromJson({
        'id': 2435,
        'date': '2026-11-22',
        'shift_code': {'id': 1, 'name': 'Shift 1', 'kind': 'work'},
        'location': {'type': 'warehouse', 'id': 1, 'name': 'Gudang Pusat'},
        'inspection_branch': null,
      });
      expect(g.isSidak, isFalse);
      expect(g.location.isWarehouse, isTrue);
    });

    test('jadwal sidak hari ini: owner bebas, SPV terkunci', () {
      final spv = InspectionToday.fromJson({
        'date': '2026-11-22',
        'free': false,
        'items': [
          {'schedule_id': 2434, 'branch_id': 12, 'branch_name': 'JUNTIKEBON', 'shift_name': 'Shift 1', 'start_time': '07:00', 'end_time': '15:00', 'inspection_id': 33},
        ],
      });
      expect(spv.unlocked, isFalse);
      expect(spv.items.single.branchId, 12);
      expect(spv.items.single.done, isTrue);
      expect(spv.items.single.hours, '07.00–15.00');
      expect(InspectionToday.fromJson({'free': true, 'items': []}).unlocked, isTrue);
      expect(const InspectionToday(legacy: true).unlocked, isTrue);
    });

    testWidgets('Jadwal saya: kerja di gudang dan sidak di outlet (360 × 800 dp)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rows = [
        MyScheduleEntry.fromJson({
          'id': 1,
          'date': today,
          'shift_code': {'id': 1, 'name': 'Shift 1', 'kind': 'work', 'start_time': '07:00', 'end_time': '15:00'},
          'location': {'type': 'warehouse', 'id': 1, 'name': 'Gudang Pusat'},
        }),
        MyScheduleEntry.fromJson({
          'id': 2,
          'date': today,
          'shift_code': {'id': 1, 'name': 'Shift 1', 'kind': 'work', 'start_time': '07:00', 'end_time': '15:00'},
          'location': {'type': 'roving', 'id': 0, 'name': 'SPV keliling'},
          'inspection_branch': {'type': 'branch', 'id': 12, 'name': 'JUNTIKEBON'},
        }),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: [mySchedulesProvider.overrideWith((ref) async => rows)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const MySchedulePage()),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Gudang Pusat'), findsOneWidget);
      expect(find.textContaining('Sidak · Shift 1'), findsOneWidget);
      expect(find.text('Outlet JUNTIKEBON'), findsOneWidget);
      expect(find.text('SPV keliling'), findsNothing);
    });
  });
}
