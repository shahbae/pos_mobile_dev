import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/expense_model.dart';
import 'package:pos_mobile/data/models/kpi_revisi_model.dart';
import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/data/models/stock_pack_model.dart';
import 'package:pos_mobile/data/repositories/kpi_repository.dart';
import 'package:pos_mobile/data/repositories/shipment_repository.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/presentation/pages/expenses/expense_form_page.dart';
import 'package:pos_mobile/presentation/pages/expenses/expense_list_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/directives_page.dart';
import 'package:pos_mobile/presentation/pages/shipments/shipment_receive_page.dart';
import 'package:pos_mobile/presentation/providers/expense_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/presentation/widgets/live_session_card.dart';
import 'package:pos_mobile/presentation/widgets/push_binder.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Kontrak: be-pos docs/api-revisi-kpi-11nov-fe.md (langkah 1–3).

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

class _FakeCamera extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(_png, name: 'foto.jpg', mimeType: 'image/jpeg');
}

class _FakeShipments implements ShipmentRepository {
  List<ReceiveLineInput>? lines;

  @override
  Future<void> receive(int id, {int? revision, List<ReceiveLineInput> lines = const []}) async {
    this.lines = lines;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeKpi implements KpiRepository {
  final List<String> calls = [];
  List<LeaderDirective> directives = const [];

  @override
  Future<List<LeaderDirective>> myDirectives() async => directives;

  @override
  Future<List<LeaderEvaluation>> myEvaluations() async => [
    LeaderEvaluation.tryFrom({
      'period': '2026-10',
      'spv_name': 'Alena',
      'photo_url': null,
      'evaluation': {'content': 'Kas rapi, opname tepat waktu.', 'updated_at': '2026-10-30T10:00:00+07:00'},
    })!,
  ];

  @override
  Future<LeaderDirective> markDirectiveDone(int id, {String note = '', Uint8List? photo}) async {
    calls.add('done:$id:$note:${photo?.length ?? 0}');
    return directives.first;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mencatat permintaan terakhir dan menjawab dengan [body].
class _Adapter implements HttpClientAdapter {
  Object body = const {'success': true, 'data': {}};
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

ShipmentLine _sirup() => ShipmentLine(
  id: 31,
  itemType: 'material',
  itemId: 9,
  name: 'Sirup Leci',
  unit: 'ml',
  qty: 6000,
  pack: StockPack(templateId: 3, name: '1 botol', baseQty: 1000, whole: 6, exact: 6),
);

ShipmentLine _gula() => ShipmentLine(id: 32, itemType: 'material', itemId: 4, name: 'Gula Merah', unit: 'gram', qty: 6300);

Shipment _shipment() => Shipment(id: 77, branchId: 12, stockRequestId: 40, status: 'shipped', revision: 2, lines: [_sirup(), _gula()]);

final _directive = LeaderDirective.fromJson({
  'id': 5,
  'spv_name': 'Alena',
  'branch_name': 'JUNTIKEBON',
  'content': 'Rapikan rak topping sebelum buka',
  'due_at': '2026-11-16T23:59:59+07:00',
  'state': 'open',
});

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, [List<Override> overrides = const []]) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.lightTheme, home: home),
);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('aturan', () {
    test('jumlah diterima wajib, dalam kemasan, dan jadi dasar stok masuk', () {
      final s = ReceiveLineInput(line: _sirup());
      expect(receiveProblems([s]).single, contains('isi jumlah yang diterima'));
      final r = s.copyWith(received: 5.5);
      expect([r.receivedBase, r.differs, r.acceptedBase], [5500, true, 5500]);
      final d = r.copyWith(damaged: 1, photo: _png);
      expect(d.acceptedBase, 4500);
      expect(receiveProblems([d]), isEmpty);
      expect(receiveProblems([d.copyWith(damaged: 6)]).single, contains('melebihi yang diterima'));
      expect(r.copyWith(clearReceived: true).received, isNull);
      expect(ReceiveLineInput(line: _gula(), received: 6300).differs, isFalse);
    });

    test('hasil selisih terima dibaca dari server', () {
      final l = ShipmentLine.fromJson({
        'id': 41, 'item_type': 'material', 'item_id': 17, 'name': 'Gula Merah', 'unit': 'gram', 'qty': '6300',
        'received_qty': '630', 'receive_diff_status': 'pending',
      });
      expect([l.receivedQty, l.receivedDiffers, l.receiveDiffLabel], [630, true, 'Selisih menunggu SPV']);
      final old = ShipmentLine.fromJson({'id': 1, 'qty': '10'});
      expect([old.receivedQty, old.receivedDiffers, old.receiveDiffLabel], [null, false, '']);
    });

    test('status ACC pengeluaran, standar harian, dan pengeluaran menunggu di shift', () {
      final e = ExpenseModel.fromJson({'id': 3, 'amount': '70000', 'approval_status': 'pending'});
      expect([e.isPendingApproval, e.approvalLabel], [true, 'Menunggu ACC SPV']);
      final r = ExpenseModel.fromJson({'id': 4, 'approval_status': 'rejected', 'approval_note': 'es masih ada'});
      expect([r.isRejected, r.approvalLabel, r.approvalNote], [true, 'Ditolak SPV', 'es masih ada']);
      expect(ExpenseModel.fromJson({'id': 5}).approvalLabel, '', reason: 'server lama = disetujui');
      expect(CostType.fromJson({'id': 1, 'name': 'Es kristal', 'daily_standard': '100000.00'}).dailyStandard, 100000);
      expect(CostType.fromJson({'id': 7, 'name': 'Listrik', 'daily_standard': null}).dailyStandard, isNull);
      expect(expenseApprovalOf({'data': {'approval_status': 'pending'}}), 'pending');
      expect(expenseApprovalOf(null), '');
      final sh = ShiftModel.fromJson({'id': 9, 'opening_cash': 0, 'total_sales': 0, 'total_expense': 60000, 'pending_expense': 115000});
      expect([sh.totalExpense, sh.pendingExpense], [60000, 115000]);
    });

    test('jadwal & sesi Live dibaca dari server', () {
      final slot = LiveSlot.fromJson({
        'schedule_id': 1141,
        'date': '2026-11-14',
        'shift_name': 'Shift 2',
        'shift_start': '2026-11-14T15:00:00+07:00',
        'shift_end': '2026-11-14T23:00:00+07:00',
        'session': null,
        'can_start': true,
      });
      expect([slot.scheduleId, slot.session, slot.canStart, slot.actionable], [1141, null, true, true]);
      final s = LiveSession.fromJson({
        'id': 3, 'started_at': '2026-11-13T19:10:00+07:00', 'ended_at': '2026-11-13T19:40:00+07:00', 'duration_minutes': 30,
        'problem': 'short', 'evaluated_at': '2026-11-13T23:05:00+07:00', 'review_status': 'pending',
        'event_status': 'PENDING', 'event_points': -0.5,
      });
      expect([s.running, s.problemLabel, s.verdictLabel], [false, 'Kurang dari 60 menit', 'Usulan potongan −0,5, menunggu SPV']);
      final cancelled = LiveSession.fromJson({
        'id': 4, 'problem': 'short', 'evaluated_at': '2026-11-13T23:05:00+07:00',
        'review_status': 'cancelled', 'reviewed_at': '2026-11-14T09:00:00+07:00',
      });
      expect(cancelled.verdictLabel, 'Usulan potongan dibatalkan SPV');
      final set = LiveSession.fromJson({
        'id': 5, 'problem': 'not_closed', 'evaluated_at': '2026-11-14T15:05:00+07:00',
        'review_status': 'approved', 'review_points': -1, 'reviewed_at': '2026-11-14T16:00:00+07:00',
      });
      expect(set.verdictLabel, 'SPV: potongan −1');
      expect(LiveSession.fromJson({'id': 6, 'evaluated_at': '2026-11-14T15:05:00+07:00'}).problemLabel, 'Tertib');
    });

    test('arahan & evaluasi dibaca dari server', () {
      expect([_directive.id, _directive.isOpen, _directive.canMarkDone, _directive.stateLabel], [5, true, true, 'Belum dikerjakan']);
      final checked = LeaderDirective.fromJson({'id': 6, 'state': 'checked', 'check_result': 'not_done', 'checked_at': '2026-11-14T10:00:00+07:00'});
      expect([checked.canMarkDone, checked.stateLabel], [false, 'Dicek SPV: tidak terlaksana']);
      expect(LeaderEvaluation.tryFrom({'period': '2026-11', 'evaluation': null}), isNull);
    });

    test('hak per role', () {
      // Ilham (karyawan), Khaerudien (leader), Alena (SPV), Admin (owner).
      expect([canDoLive({'karyawan'}), canDoLive({'leader'}), canDoLive({'supervisor'}), canDoLive({'owner'})], [true, true, false, false]);
      expect([canSeeDirectives({'leader'}), canSeeDirectives({'karyawan'}), canSeeDirectives({'supervisor'})], [true, false, false]);
    });
  });

  group('permintaan ke server', () {
    late _Adapter adapter;
    late ApiService api;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
    });

    setUp(() {
      adapter = _Adapter();
      api = ApiService()..dio.httpClientAdapter = adapter;
    });

    Map<String, String> fields(RequestOptions o) => {for (final f in (o.data as FormData).fields) f.key: f.value};
    Map<String, String> files(RequestOptions o) => {for (final f in (o.data as FormData).files) f.key: f.value.filename ?? ''};

    test('terima tanpa rusak: JSON, semua baris membawa received_qty satuan dasar', () async {
      await ShipmentRepository(api).receive(77, revision: 2, lines: [
        ReceiveLineInput(line: _sirup(), received: 6),
        ReceiveLineInput(line: _gula(), received: 630),
      ]);
      final o = adapter.last!;
      expect(o.path, '/shipments/77/receive');
      expect(o.data, {
        'revision': 2,
        'lines': [
          {'id': 31, 'received_qty': '6000'},
          {'id': 32, 'received_qty': '630'},
        ],
      });
    });

    test('terima dengan rusak: multipart, rusak ikut baris + foto per baris', () async {
      await ShipmentRepository(api).receive(77, revision: 2, lines: [
        ReceiveLineInput(line: _sirup(), received: 6, damaged: 1, photo: _png),
        ReceiveLineInput(line: _gula(), received: 6300),
      ]);
      final o = adapter.last!;
      expect(jsonDecode(fields(o)['lines']!), [
        {'id': 31, 'received_qty': '6000', 'damaged_qty': '1000', 'expired_qty': '0'},
        {'id': 32, 'received_qty': '6300'},
      ]);
      expect(fields(o)['revision'], '2');
      expect(files(o), {'photo_31': 'rusak-77-31.jpg'});
    });

    test('komplain kualitas membawa barangnya', () async {
      await KpiRepository(api).createQualityComplaint(
        shipmentId: 77, branchId: 12, content: 'asam', photo: _png, itemType: 'material', itemId: 9,
      );
      final f = fields(adapter.last!);
      expect([f['kind'], f['item_type'], f['item_id']], ['production_quality', 'material', '9']);
    });

    test('Live: mulai JSON, selesai multipart dengan screenshot', () async {
      adapter.body = {'success': true, 'data': {'id': 9, 'started_at': '2026-11-14T15:05:00+07:00'}};
      final repo = KpiRepository(api);
      final s = await repo.startLive(1141);
      expect([adapter.last!.path, adapter.last!.data, s.id, s.running], ['/me/live-sessions/start', {'schedule_id': 1141}, 9, true]);
      await repo.finishLive(9, _png);
      expect([adapter.last!.path, files(adapter.last!)], ['/me/live-sessions/9/finish', {'photo': 'live-9.jpg'}]);
      await repo.addLiveScreenshot(9, _png);
      expect(adapter.last!.path, '/me/live-sessions/9/screenshot');
    });

    test('arahan: tandai dikerjakan dengan catatan dan foto', () async {
      adapter.body = {'success': true, 'data': {'id': 5, 'state': 'done'}};
      final d = await KpiRepository(api).markDirectiveDone(5, note: ' sudah ', photo: _png);
      expect([adapter.last!.path, fields(adapter.last!), files(adapter.last!), d.state],
          ['/me/directives/5/done', {'note': 'sudah'}, {'photo': 'arahan-5.jpg'}, 'done']);
    });
  });

  group('layar (tema app, ukuran HP)', () {
    testWidgets('Terima kiriman: jumlah diterima wajib, beda dari surat jalan diberi tahu', (tester) async {
      _phone(tester);
      final repo = _FakeShipments();
      await tester.pumpWidget(_app(ShipmentReceivePage(shipment: _shipment()), [shipmentRepositoryProvider.overrideWithValue(repo)]));
      await tester.pumpAndSettle();

      expect(find.text('Isi jumlah diterima: 2 barang lagi'), findsOneWidget);
      await tester.tap(find.text('Terima Kiriman'));
      await tester.pumpAndSettle();
      expect(find.text('Sirup Leci: isi jumlah yang diterima.'), findsOneWidget);
      expect(repo.lines, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Jumlah diterima').at(0), '6');
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah diterima').at(1), '630');
      await tester.pumpAndSettle();
      expect(find.textContaining('Beda dari surat jalan'), findsOneWidget);
      expect(find.text('Masuk stok 630 gram'), findsOneWidget);

      await tester.tap(find.text('Terima Kiriman'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SPV akan memeriksanya'), findsOneWidget);
      await tester.tap(find.text('Ya, terima'));
      await tester.pumpAndSettle();
      expect(repo.lines!.map((l) => l.receivedBase), [6000, 630]);
    });

    testWidgets('Kartu Live: tiga keadaan tombol', (tester) async {
      _phone(tester);
      final tapped = <String>[];
      Widget tile(LiveSlot s) => _app(Scaffold(
        body: LiveSlotTile(
          slot: s,
          onStart: () => tapped.add('start'),
          onFinish: () => tapped.add('finish'),
          onScreenshot: () => tapped.add('shot'),
        ),
      ));

      await tester.pumpWidget(tile(LiveSlot.fromJson({
        'schedule_id': 1, 'shift_name': 'Shift 2', 'shift_start': '2026-11-14T15:00:00+07:00',
        'shift_end': '2026-11-14T23:00:00+07:00', 'can_start': true,
      })));
      expect(find.text('Live TikTok · Shift 2 15.00–23.00'), findsOneWidget);
      await tester.tap(find.text('Mulai Live'));

      await tester.pumpWidget(tile(LiveSlot.fromJson({
        'schedule_id': 1, 'can_finish': true, 'session': {'id': 9, 'started_at': '2026-11-14T15:05:00+07:00'},
      })));
      expect(find.textContaining('Live berjalan sejak 15.05'), findsOneWidget);
      await tester.tap(find.text('Selesai + screenshot'));

      await tester.pumpWidget(tile(LiveSlot.fromJson({
        'schedule_id': 1, 'can_add_screenshot': true,
        'session': {
          'id': 9, 'started_at': '2026-11-14T08:00:00+07:00', 'ended_at': '2026-11-14T15:00:00+07:00', 'closed_by_system': true,
          'problem': 'not_closed', 'evaluated_at': '2026-11-14T15:05:00+07:00', 'review_status': 'pending',
        },
      })));
      expect(find.textContaining('ditutup sistem'), findsOneWidget);
      expect(find.text('Penilaian: Lupa menekan Selesai.'), findsOneWidget);
      expect(find.text('Menunggu keputusan SPV.'), findsOneWidget);
      await tester.tap(find.text('Kirim screenshot'));
      expect(tapped, ['start', 'finish', 'shot']);
    });

    testWidgets('Arahan SPV: tandai dikerjakan dengan catatan + foto; evaluasi terbaca', (tester) async {
      _phone(tester);
      ImagePickerPlatform.instance = _FakeCamera();
      final kpi = _FakeKpi()..directives = [_directive];
      await tester.pumpWidget(_app(const DirectivesPage(), [kpiRepositoryProvider.overrideWithValue(kpi)]));
      await tester.pumpAndSettle();

      expect(find.text('Rapikan rak topping sebelum buka'), findsOneWidget);
      await tester.tap(find.text('Sudah dikerjakan'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Catatan (opsional)'), 'rak sudah rapi');
      await tester.tap(find.text('Foto bukti (opsional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(kpi.calls, ['done:5:rak sudah rapi:${_png.length}']);

      await tester.tap(find.text('Evaluasi'));
      await tester.pumpAndSettle();
      expect(find.text('Evaluasi Oktober 2026'), findsOneWidget);
      expect(find.text('Kas rapi, opname tepat waktu.'), findsOneWidget);
    });

    testWidgets('Notifikasi arahan membuka halaman Arahan SPV', (tester) async {
      _phone(tester);
      final kpi = _FakeKpi()..directives = [_directive];
      await tester.pumpWidget(_app(
        Builder(builder: (context) => Scaffold(
          body: Center(child: ElevatedButton(onPressed: () => openPushTarget(context, 'app:/directives'), child: const Text('buka'))),
        )),
        [kpiRepositoryProvider.overrideWithValue(kpi)],
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.byType(DirectivesPage), findsOneWidget);
    });

    testWidgets('Pengeluaran: standar harian di form, status ACC di daftar', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const ExpenseFormPage(), [
        costTypesProvider.overrideWith((ref) async => const [CostType(id: 1, name: 'Es kristal', dailyStandard: 100000)]),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-type-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Es kristal').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Standar harian Rp'), findsOneWidget);
      expect(find.textContaining('menunggu ACC SPV'), findsOneWidget);
    });

    testWidgets('Pengeluaran: status ACC di daftar', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(Scaffold(
        body: Column(children: [
          ExpenseApprovalPill(ExpenseModel.fromJson({'id': 1, 'approval_status': 'pending'})),
          ExpenseApprovalPill(ExpenseModel.fromJson({'id': 2, 'approval_status': 'rejected'})),
        ]),
      )));
      expect(find.text('Menunggu ACC SPV'), findsOneWidget);
      expect(find.text('Ditolak SPV'), findsOneWidget);
    });
  });
}
