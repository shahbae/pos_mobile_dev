import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/data/models/branch_return_model.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/data/models/sop_model.dart';
import 'package:pos_mobile/data/repositories/branch_return_repository.dart';
import 'package:pos_mobile/data/repositories/sop_repository.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/presentation/pages/attendance/work_gate.dart';
import 'package:pos_mobile/presentation/pages/returns/branch_return_page.dart';
import 'package:pos_mobile/presentation/pages/sop/sop_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_return_provider.dart';
import 'package:pos_mobile/presentation/providers/sop_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Revisi owner 26 Nov 2026: kunci 5 menu sebelum absen, posisi kasir, lembur
// dihitung bertugas, Retur Stok, dan SOP.

class _Adapter implements HttpClientAdapter {
  RequestOptions? last;
  String? lastBody;
  final Object responseData;
  _Adapter(this.responseData);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    if (requestStream != null) {
      final bytes = await requestStream.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      lastBody = utf8.decode(bytes);
    }
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': responseData}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

MyDay _day({bool open = false, String? shiftDuty, Map<String, dynamic>? overtime, bool auto = false}) => MyDay.fromJson({
      'date': '2026-11-26',
      'shifts': [
        if (shiftDuty != null)
          {
            'schedule_id': 1,
            'date': '2026-11-26',
            'shift_code': {'id': 1, 'name': 'Shift 1', 'kind': 'work'},
            'duty': shiftDuty,
            'location': {'type': 'branch', 'id': 12, 'name': 'JUNTIKEBON'},
            'status': open ? 'checked_in' : 'upcoming',
            'attendance_id': open ? 9 : null,
          },
      ],
      'attendances': [
        if (open) {'id': 9, 'user_id': 42, 'attendance_date': '2026-11-26', 'check_in_at': '2026-11-26T07:00:00+07:00'},
      ],
      'open_attendance_id': open ? 9 : null,
      'active_overtime': overtime,
      'auto_checkout': auto,
    });

class _FakeReturns extends BranchReturnRepository {
  _FakeReturns() : super(ApiService());
  Map<String, String>? sent;

  @override
  Future<List<BranchReturnItem>> items() async => const [
        BranchReturnItem(itemType: 'plastic', itemId: 3, name: 'Plastik Cup', unit: 'pcs', systemQty: 120),
        BranchReturnItem(itemType: 'material', itemId: 58, name: 'Bubuk Coklat', unit: 'gram', systemQty: 500),
        BranchReturnItem(itemType: 'sedotan', itemId: 2, name: 'Sedotan Habis', unit: 'pcs', systemQty: 0),
      ];

  @override
  Future<BranchReturnDoc> create({required List<BranchReturnItem> items, required Map<String, String> qty, String note = ''}) async {
    sent = qty;
    return const BranchReturnDoc(id: 1);
  }

  @override
  Future<List<BranchReturnDoc>> history() async => const [];
}

class _FakeSops extends SopRepository {
  _FakeSops() : super(ApiService());
  @override
  Future<List<Sop>> list() async => const [
        Sop(id: 1, title: 'SOP Cuci Gelas', description: 'Bilas tiga kali', fileType: 'pdf', fileUrl: 'http://x/sop.pdf'),
      ];
}

/// Tombol bergaya (ElevatedButton.icon = subkelas privat ElevatedButton).
Finder _button(String text) =>
    find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)).first;

Future<void> _pump(WidgetTester tester, Widget page, List<Override> overrides) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.lightTheme, home: page),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    await initializeDateFormatting('id_ID', null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  group('kunci 5 menu (workMenuBlock)', () {
    test('owner bebas walau belum absen', () {
      expect(workMenuBlock(held: ['owner'], status: AttendanceGateStatus.notCheckedIn, day: null, cashier: true), isNull);
    });
    test('belum absen: semua menu kerja terkunci, termasuk leader & SPV', () {
      for (final held in [
        ['karyawan'],
        ['leader'],
        ['supervisor'],
      ]) {
        expect(workMenuBlock(held: held, status: AttendanceGateStatus.notCheckedIn, day: null, cashier: false), kWorkMenuNeedCheckIn);
        expect(workMenuBlock(held: held, status: AttendanceGateStatus.checkedOut, day: null, cashier: true), kWorkMenuNeedCheckIn);
      }
    });
    test('penyaji: audit/waste/retur/ceklis boleh, Kasir tidak', () {
      final day = _day(open: true, shiftDuty: 'server');
      expect(workMenuBlock(held: ['karyawan'], status: gateStatusOfDay(day), day: day, cashier: false), isNull);
      expect(workMenuBlock(held: ['karyawan'], status: gateStatusOfDay(day), day: day, cashier: true), kWorkMenuNotCashier);
    });
    test('kasir & penyaji kasir boleh Kasir', () {
      for (final d in ['cashier', 'both']) {
        final day = _day(open: true, shiftDuty: d);
        expect(workMenuBlock(held: ['karyawan'], status: gateStatusOfDay(day), day: day, cashier: true), isNull);
      }
    });
  });

  group('lembur dihitung bertugas (my-day)', () {
    test('lembur aktif tanpa absen biasa = bertugas, posisi dari lembur', () {
      final day = _day(overtime: {
        'id': 2,
        'duty': 'server',
        'location': {'type': 'branch', 'id': 12, 'name': 'JUNTIKEBON'},
      });
      expect(day.activeOvertime?.location.name, 'JUNTIKEBON');
      expect(day.onDuty, isTrue);
      expect(gateStatusOfDay(day), AttendanceGateStatus.working);
      expect(day.currentDuty, 'server');
      expect(workMenuBlock(held: ['karyawan'], status: gateStatusOfDay(day), day: day, cashier: true), kWorkMenuNotCashier);
    });
    test('auto_checkout terbaca', () {
      expect(_day(auto: true).autoCheckout, isTrue);
      expect(_day().autoCheckout, isFalse);
    });
  });

  group('Retur Stok', () {
    test('repository: hanya barang berisi jumlah yang dikirim', () async {
      final adapter = _Adapter({'id': 15, 'return_status': 'pending', 'items': []});
      final api = ApiService()..dio.httpClientAdapter = adapter;
      const items = [
        BranchReturnItem(itemType: 'plastic', itemId: 3, name: 'Plastik Cup'),
        BranchReturnItem(itemType: 'material', itemId: 58, name: 'Bubuk Coklat'),
      ];
      final doc = await BranchReturnRepository(api).create(items: items, qty: {'plastic-3': '50', 'material-58': ''}, note: 'rusak');
      expect(adapter.last!.path, '/branch-returns');
      final body = jsonDecode(adapter.lastBody!) as Map<String, dynamic>;
      expect(body['note'], 'rusak');
      expect(body['items'], [
        {'item_type': 'plastic', 'item_id': 3, 'qty': '50'},
      ]);
      expect(doc.id, 15);
    });

    testWidgets('layar: barang tanpa stok disembunyikan, jumlah dikirim', (tester) async {
      final repo = _FakeReturns();
      await _pump(tester, const BranchReturnPage(), [branchReturnRepositoryProvider.overrideWithValue(repo)]);
      expect(tester.takeException(), isNull);
      expect(find.text('Plastik Cup'), findsOneWidget);
      expect(find.text('Bubuk Coklat'), findsOneWidget);
      expect(find.text('Sedotan Habis'), findsNothing);
      expect(tester.widget<ButtonStyleButton>(_button('Kirim retur')).onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('retur-plastic-3')), '50');
      await tester.pump();
      final send = _button('Kirim retur (1 barang)');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim'));
      await tester.pumpAndSettle();
      expect(repo.sent, {'plastic-3': '50'});
    });

    testWidgets('layar: jumlah melebihi stok ditolak sebelum dikirim', (tester) async {
      final repo = _FakeReturns();
      await _pump(tester, const BranchReturnPage(), [branchReturnRepositoryProvider.overrideWithValue(repo)]);
      await tester.enterText(find.byKey(const ValueKey('retur-plastic-3')), '500');
      await tester.pump();
      final send = _button('Kirim retur (1 barang)');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      expect(find.textContaining('stok sistem tinggal 120'), findsOneWidget);
      expect(repo.sent, isNull);
    });
  });

  testWidgets('SOP: daftar tampil dengan judul dan keterangan', (tester) async {
    await _pump(tester, const SopPage(), [sopRepositoryProvider.overrideWithValue(_FakeSops())]);
    expect(tester.takeException(), isNull);
    expect(find.text('SOP Cuci Gelas'), findsOneWidget);
    expect(find.text('Bilas tiga kali'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });
}
