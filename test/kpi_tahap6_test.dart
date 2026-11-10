import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/repositories/kpi_repository.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/presentation/pages/kpi/cash_deposit_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/inspection_form_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/inspection_list_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_dispute_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/pages/kpi/my_kpi_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/photo_checklist_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/photo_checklist_card.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Tahap 6 langkah 5 (app kasir 1.0.23+41): skor & sanggahan, tim leader,
/// ceklis foto, setoran, sidak. Bentuk JSON diambil dari be-pos
/// `docs/api-kpi-tahap6-fe.md` dan tag JSON di `origin/dev` 4 Nov 2026.

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements KpiRepository {
  MyKpi mineResult = const MyKpi(period: '2026-11');
  Object? mineError;
  KpiTeam teamResult = const KpiTeam(period: '2026-11');
  List<ChecklistSet> checklist = const [];
  List<CashDeposit> deposits = const [];
  List<InspectionItem> items = const [];
  List<Inspection> inspectionRows = const [];
  final submitted = <String>[];

  @override
  Future<MyKpi> mine({String? period}) async {
    if (mineError != null) throw mineError!;
    return mineResult;
  }

  @override
  Future<KpiTeam> team({String? period}) async => teamResult;

  @override
  Future<List<ChecklistSet>> myChecklist() async => checklist;

  @override
  Future<void> submitChecklist({required int scheduleId, required int itemId, Uint8List? photo, String? unusedReason}) async {
    submitted.add('$scheduleId:$itemId:${photo == null ? 'unused:$unusedReason' : 'photo'}');
  }

  @override
  Future<List<CashDeposit>> cashDeposits({int page = 1, int limit = 50}) async => deposits;

  @override
  Future<List<InspectionItem>> inspectionItems() async => items;

  @override
  Future<List<Inspection>> inspections({int? branchId, String? from, String? to, int limit = 50}) async =>
      inspectionRows;

  @override
  Future<Inspection> inspection(int id) async => inspectionRows.firstWhere((i) => i.id == id);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Mencatat permintaan terakhir dan menjawab dengan [status] + [body].
class _Adapter implements HttpClientAdapter {
  int status = 200;
  Object body = const {'success': true, 'data': {}};
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

// ------------------------------------------------------------------ data uji

final _now = DateTime.now();
String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _event({
  int id = 162,
  String code = 'C3.1',
  double points = -0.4,
  String status = 'APPROVED',
  bool canDispute = true,
  Map<String, dynamic>? dispute,
}) =>
    {
      'id': id,
      'period': '2026-11',
      'module': 'CREW',
      'occurred_at': _iso(_now.subtract(const Duration(hours: 3))),
      'branch_id': 8,
      'branch_name': 'JUNTIKEDOKAN',
      'user_id': 7,
      'user_name': 'Ilham',
      'indicator_code': code,
      'indicator_name': 'Komunikasi & attitude kasir ke pembeli',
      'scope': 'person',
      'event_type': 'ATTITUDE_BURUK',
      'points': points,
      'source': 'MANUAL',
      'status': status,
      'effective_at': _iso(_now.subtract(const Duration(hours: 3))),
      'note': 'Tidak menyapa pembeli (CCTV)',
      'evidence_url': null,
      'assessor_id': 2,
      'assessor_name': 'Alena',
      'ref_type': '',
      'ref_id': 0,
      'reversed_by': null,
      'reversed_at': null,
      'reverse_reason': '',
      'assigned_by': null,
      'assign_reason': '',
      'needs_person': false,
      'dispute': dispute,
      'can_dispute': canDispute,
      'dispute_until': _iso(_now.add(const Duration(days: 2))),
      'created_at': _iso(_now),
    };

Map<String, dynamic> _score({String module = 'CREW', double? score = 83.5, List<Map<String, dynamic>>? events}) => {
      'period': '2026-11',
      'module': module,
      'user_id': 7,
      'name': 'Ilham',
      'branch_id': 8,
      'branch_name': 'JUNTIKEDOKAN',
      'score': score,
      'bonus': 0,
      'predicate': score == null ? '' : 'Baik',
      'status': 'running',
      'detail': {
        'module': module,
        'earned': 84,
        'applicable': 100,
        'penalty': 0.5,
        'score': score,
        'bonus': 0,
        'technical': score,
        'predicate': 'Baik',
        'pools': [
          {
            'code': 'C3',
            'name': 'Pelayanan Kasir',
            'method': 'deduct',
            'weight': 10,
            'score': 9.6,
            'na': false,
            'indicators': [
              {
                'code': 'C3.1',
                'name': 'Komunikasi & attitude',
                'rule_type': 'EVENT_DEDUCT',
                'kind': 'MANUAL',
                'scope': 'person',
                'cap': 3,
                'value': 0.4,
                'raw': 0.4,
                'na': false,
                'events': 1,
              },
            ],
          },
          {'code': 'L1', 'name': 'Omzet', 'method': 'measure', 'weight': 20, 'score': 0, 'na': true, 'indicators': []},
        ],
      },
      'events': events ?? [_event()],
    };

Map<String, dynamic> _item(int id, String name, String status, {bool allowUnused = false, String reject = ''}) => {
      'item_id': id,
      'name': name,
      'indicator': 'C1.1',
      'allow_unused': allowUnused,
      'status': status,
      'photo_id': status == 'missing' ? null : id * 10,
      'photo_url': null,
      'unused': false,
      'unused_reason': '',
      'taken_at': status == 'missing' ? null : _iso(_now.subtract(const Duration(minutes: 20))),
      'uploaded_by': status == 'missing' ? null : 9,
      'uploaded_by_name': status == 'missing' ? '' : 'Diyan',
      'reject_reason': reject,
      'late': status == 'approved',
      'can_submit': status == 'missing' || status == 'rejected',
    };

Map<String, dynamic> _phase(String phase, {required DateTime opens, required DateTime cutoff, required List<Map<String, dynamic>> items}) => {
      'phase': phase,
      'opens_at': _iso(opens),
      'deadline': phase == 'opening' ? _iso(opens.add(const Duration(minutes: 90))) : null,
      'cutoff': _iso(cutoff),
      'open': !_now.isBefore(opens) && _now.isBefore(cutoff),
      'complete': items.every((i) => i['status'] == 'pending' || i['status'] == 'approved'),
      'items': items,
    };

ChecklistSet _set({int branchId = 8, List<Map<String, dynamic>>? phases}) => ChecklistSet.fromJson({
      'schedule_id': 1077,
      'date': '2026-11-05',
      'branch_id': branchId,
      'branch_name': 'JUNTIKEDOKAN',
      'shift_code_id': 1,
      'shift_name': 'Shift 1',
      'duty': 'cashier',
      'judged': true,
      'phases': phases ??
          [
            _phase('opening', opens: _now.subtract(const Duration(hours: 1)), cutoff: _now.add(const Duration(hours: 6)), items: [
              _item(1, 'Area luar', 'approved'),
              _item(2, 'Menu', 'missing'),
              _item(3, 'Neon box bawah', 'rejected', reject: 'Buram'),
            ]),
            _phase('closing', opens: _now.add(const Duration(hours: 2)), cutoff: _now.add(const Duration(hours: 9)), items: [
              _item(7, 'Laporan POS', 'missing'),
              _item(9, 'Teh sisa', 'missing', allowUnused: true),
            ]),
          ],
    });

// ------------------------------------------------------------------ pompa

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  _Repo repo, {
  List<String> roles = const ['karyawan'],
  List<Override> extra = const [],
}) async {
  // HP 360 × 800 dp. Tema app wajib ikut: tombol bertema lebar penuh pernah
  // hilang di dalam Row tanpa ketahuan tes (1 Nov 2026).
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(
        (ref) => _FixedAuth(AuthState(status: AuthStatus.authenticated, role: roles.first, roles: roles, branchId: 8)),
      ),
      kpiRepositoryProvider.overrideWithValue(repo),
      ...extra,
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
}

/// Daftar vertikal terluar halaman (bukan PageView tab atau TextField).
final _vScroll = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Finder _button(String text) =>
    find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

/// Tombol ada, terlihat di layar HP, dan bisa ditekan.
void _expectTappable(WidgetTester tester, String text) => _expectTappableAt(tester, find.text(text));

void _expectTappableAt(WidgetTester tester, Finder label) {
  final f = find.ancestor(of: label, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  expect(f, findsWidgets, reason: 'tombol $label tidak ada');
  final b = tester.widget<ButtonStyleButton>(f.first);
  expect(b.onPressed, isNotNull, reason: 'tombol $label mati');
  final r = tester.getRect(f.first);
  expect(r.width, greaterThan(40), reason: 'tombol $label selebar ${r.width}');
  expect(r.right, lessThanOrEqualTo(360), reason: 'tombol $label keluar layar');
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('model', () {
    test('skor /me/kpi: skor, pool N/A, kejadian, sanggahan', () {
      final v = MyKpi.fromJson({
        'period': '2026-11',
        'input_close_at': '2026-12-04T00:00:00+07:00',
        'scores': [
          _score(events: [
            _event(),
            _event(id: 163, canDispute: false, dispute: {
              'id': 5,
              'event_id': 163,
              'user_id': 7,
              'user_name': 'Ilham',
              'reason': 'Saya penyaji',
              'photo_url': null,
              'status': 'rejected',
              'decided_by': 2,
              'decided_by_name': 'Alena',
              'decided_at': _iso(_now),
              'decision_note': 'Jadwal kasir',
              'created_at': _iso(_now),
            }),
          ]),
        ],
      });
      final s = v.scores.single;
      expect(s.score, 83.5);
      expect(s.detail!.penalty, 0.5);
      expect(s.detail!.pools.last.na, isTrue);
      expect(s.events.first.canDispute, isTrue);
      expect(s.events.last.dispute!.status, 'rejected');
      expect(s.events.last.dispute!.decisionNote, 'Jadwal kasir');
      expect(v.inputCloseAt!.toUtc(), DateTime.utc(2026, 12, 3, 17));
    });

    test('skor null (semua N/A) tidak dibaca sebagai 0', () {
      final s = KpiScore.fromJson(_score(score: null));
      expect(s.score, isNull);
      expect(kpiNum(s.score), '—');
    });

    test('angka berkoma Indonesia, maksimal 2 desimal', () {
      expect(kpiNum(83.5), '83,5');
      expect(kpiNum(14.7794), '14,78');
      expect(kpiPoints(-0.4), '−0,4');
      expect(kpiPoints(1.5), '+1,5');
    });

    test('setoran: nominal decimal dikirim server sebagai string, tanggal kolom date', () {
      final d = CashDeposit.fromJson({
        'id': 3,
        'branch_id': 8,
        'branch_name': 'JUNTIKEDOKAN',
        'operational_date': '2026-11-04T00:00:00+07:00',
        'leader_id': 11,
        'leader_name': 'Aenah',
        'amount': '1250000',
        'note': '',
        'photo_url': 'https://x.invalid/uploads/kpi/a.jpg',
        'uploaded_at': _iso(_now),
        'transfer_at': _iso(_now),
        'status': 'pending',
        'late': true,
        'verified_by': null,
        'verified_by_name': '',
        'rejected_by': null,
        'rejected_by_name': '',
        'reject_reason': '',
        'event_id': null,
      });
      expect(d.amount, 1250000);
      expect(d.operationalDate, '2026-11-04');
      expect(d.late, isTrue);
      expect(d.verifiedByName, isNull);
    });

    test('ceklis: yang perlu dikirim dihitung dari jam fase, bukan can_submit saat dimuat', () {
      final s = _set();
      final opening = s.phaseOf('opening')!;
      expect(opening.sentCount, 1);
      // Menu (missing) + Neon box (rejected); Area luar sudah di-ACC.
      expect(ChecklistSummary.of([s], now: _now).toSend, 2);
      expect(ChecklistSummary.of([s], now: _now).rejected, 1);
      // Closing belum dibuka sekarang …
      expect(ChecklistSummary.of([s], now: _now, phase: 'closing').toSend, 0);
      // … tapi dihitung begitu jamnya lewat, walau datanya dimuat sebelumnya.
      final later = _now.add(const Duration(hours: 3));
      expect(ChecklistSummary.of([s], now: later, phase: 'closing').names, ['Laporan POS', 'Teh sisa']);
      // Lewat batas kirim: tidak ada lagi yang bisa dikirim.
      expect(ChecklistSummary.of([s], now: _now.add(const Duration(hours: 10))).toSend, 0);
      // Cabang lain tidak dihitung saat Tutup Shift.
      expect(ChecklistSummary.of([s], now: _now, branchId: 2).toSend, 0);
    });

    test('sidak: senin minggu berjalan', () {
      expect(weekStartOf(DateTime(2026, 11, 5, 14)), DateTime(2026, 11, 2)); // Kamis → Senin
      expect(weekStartOf(DateTime(2026, 11, 8, 23)), DateTime(2026, 11, 2)); // Minggu → Senin
      expect(weekStartOf(DateTime(2026, 11, 9, 1)), DateTime(2026, 11, 9)); // Senin
    });

    test('cabang: koordinat & radius ikut dibaca', () {
      final b = BranchModel.fromJson({'id': 8, 'name': 'JUNTIKEDOKAN', 'attendance_radius': 150, 'status': 'active'});
      expect(b.hasGeo, isFalse);
      expect(b.attendanceRadius, 150);
      final c = BranchModel.fromJson({'id': 12, 'name': 'JUNTIKEBON', 'latitude': -6.7, 'longitude': 108.5});
      expect(c.hasGeo, isTrue);
      expect(c.attendanceRadius, 100);
    });
  });

  group('hak per role (cermin be-pos)', () {
    test('karyawan: skor & ceklis, tanpa tim/setoran/sidak', () {
      const r = {'karyawan'};
      expect(canSeeOwnKpi(r), isTrue);
      expect(canUsePhotoChecklist(r), isTrue);
      expect(canSeeTeamKpi(r), isFalse);
      expect(canSendCashDeposit(r), isFalse);
      expect(canInspect(r), isFalse);
    });
    test('leader: skor, ceklis, tim, setoran; tidak sidak', () {
      const r = {'leader'};
      expect(canSeeOwnKpi(r) && canUsePhotoChecklist(r) && canSeeTeamKpi(r) && canSendCashDeposit(r), isTrue);
      expect(canInspect(r), isFalse);
    });
    test('SPV & owner: sidak; SPV punya skor SPV sendiri (Tahap 7), owner tidak', () {
      for (final r in [
        {'supervisor'},
        {'owner'},
      ]) {
        expect(canInspect(r), isTrue);
        expect(canUsePhotoChecklist(r), isFalse);
      }
      expect(canSeeOwnKpi({'supervisor'}), isTrue);
      expect(canSeeOwnKpi({'owner'}), isFalse);
      expect(canSeeOwnKpi({'owner', 'supervisor'}), isFalse, reason: 'owner tidak dinilai');
    });
    test('leader + SPV: semuanya (server menolak sidak di outlet yang dipimpinnya)', () {
      const r = {'leader', 'supervisor'};
      expect(canSeeOwnKpi(r) && canSeeTeamKpi(r) && canSendCashDeposit(r) && canInspect(r), isTrue);
    });
    test('finance & produksi: tidak ada menu KPI', () {
      for (final r in [
        {'finance'},
        {'produksi'},
      ]) {
        expect(canSeeOwnKpi(r) || canInspect(r) || canSendCashDeposit(r), isFalse);
      }
    });
  });

  group('permintaan ke server', () {
    late _Adapter adapter;
    late KpiRepository repo;

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
      final api = ApiService()..dio.httpClientAdapter = adapter;
      repo = KpiRepository(api);
    });

    Map<String, String> fields(RequestOptions o) => {for (final f in (o.data as FormData).fields) f.key: f.value};
    Map<String, String> files(RequestOptions o) =>
        {for (final f in (o.data as FormData).files) f.key: f.value.filename ?? ''};

    test('ceklis "belum dipakai": unused=true + alasan, tanpa foto', () async {
      await repo.submitChecklist(scheduleId: 1077, itemId: 9, unusedReason: 'Teh habis terjual');
      final o = adapter.last!;
      expect(o.path, '/me/photo-checklist');
      expect(fields(o), {'schedule_id': '1077', 'item_id': '9', 'unused': 'true', 'unused_reason': 'Teh habis terjual'});
      expect(files(o), isEmpty);
    });

    test('ceklis berfoto: berkas "photo" berakhiran .jpg (server menolak ekstensi lain)', () async {
      await repo.submitChecklist(scheduleId: 1077, itemId: 2, photo: Uint8List.fromList([1, 2, 3]));
      final o = adapter.last!;
      expect(fields(o).containsKey('unused'), isFalse);
      expect(files(o)['photo'], endsWith('.jpg'));
    });

    test('sanggahan: event_id, reason, foto opsional', () async {
      adapter.body = {
        'success': true,
        'data': {'id': 5, 'event_id': 162, 'reason': 'Saya penyaji', 'status': 'open', 'created_at': _iso(_now)},
      };
      final d = await repo.dispute(eventId: 162, reason: 'Saya penyaji');
      expect(d.status, 'open');
      expect(fields(adapter.last!), {'event_id': '162', 'reason': 'Saya penyaji'});
      expect(files(adapter.last!), isEmpty);
    });

    test('setoran: nominal bulat, tanggal operasional, foto wajib', () async {
      adapter.body = {
        'success': true,
        'data': {'id': 9, 'operational_date': '2026-11-04T00:00:00Z', 'amount': '1250000', 'status': 'pending', 'late': false},
      };
      final d = await repo.createCashDeposit(
          operationalDate: '2026-11-04', amount: 1250000, photos: [Uint8List.fromList([1])], note: 'Shift 1 & 2');
      expect(d.amount, 1250000);
      expect(fields(adapter.last!), {'operational_date': '2026-11-04', 'amount': '1250000', 'note': 'Shift 1 & 2'});
      expect(files(adapter.last!)['photo'], endsWith('-1.jpg'));
    });

    test('sidak: results JSON, foto temuan photo_<item_id>, tenggat kirim 3 menit', () async {
      adapter.status = 201;
      adapter.body = {
        'success': true,
        'data': {'id': 4, 'branch_id': 12, 'scored': true, 'failed_count': 1},
      };
      await repo.createInspection(
        branchId: 12,
        latitude: -6.7,
        longitude: 108.5,
        inspectorPhoto: Uint8List.fromList([1]),
        answers: [
          const InspectionAnswer(itemId: 1, passed: true),
          InspectionAnswer(itemId: 2, passed: false, note: 'Lantai kotor', photo: Uint8List.fromList([2])),
        ],
      );
      final o = adapter.last!;
      expect(o.sendTimeout, const Duration(minutes: 3));
      final f = fields(o);
      expect(f['branch_id'], '12');
      expect(jsonDecode(f['results']!), [
        {'item_id': 1, 'passed': true, 'note': ''},
        {'item_id': 2, 'passed': false, 'note': 'Lantai kotor'},
      ]);
      expect(files(o).keys.toSet(), {'photo', 'photo_2'});
    });

    test('galat KPI membawa code; kpi_not_active jadi KpiNotActive', () async {
      adapter.status = 409;
      adapter.body = {'success': false, 'message': 'butir ini sudah dikirim', 'code': 'checklist_already_sent'};
      await expectLater(
        repo.submitChecklist(scheduleId: 1, itemId: 2, photo: Uint8List.fromList([1])),
        throwsA(isA<KpiApiError>().having((e) => e.code, 'code', 'checklist_already_sent')),
      );
      adapter.body = {'success': false, 'message': 'KPI belum berlaku untuk periode ini', 'code': 'kpi_not_active'};
      await expectLater(repo.mine(period: '2026-10'), throwsA(isA<KpiNotActive>()));
    });

    test('butir sidak: hanya yang aktif, urut kelompok lalu sort', () async {
      adapter.body = {
        'success': true,
        'data': [
          {'id': 30, 'group': 'info', 'name': 'Taste test', 'sort': 1, 'is_active': true},
          {'id': 2, 'group': 'L6.1A', 'name': 'Area samping', 'sort': 2, 'is_active': true},
          {'id': 1, 'group': 'L6.1A', 'name': 'Area depan', 'sort': 1, 'is_active': true},
          {'id': 9, 'group': 'L6.1B', 'name': 'Mixer lama', 'sort': 1, 'is_active': false},
        ],
      };
      final items = await repo.inspectionItems();
      expect(items.map((i) => i.id), [1, 2, 30]);
    });
  });

  group('layar (360 × 800 dp, tema app)', () {
    testWidgets('Skor KPI karyawan: skor, rincian, kejadian, tombol Sanggah; tanpa tab Tim', (tester) async {
      final repo = _Repo()..mineResult = MyKpi.fromJson({'period': '2026-11', 'scores': [_score()]});
      await _pump(tester, const MyKpiPage(), repo);
      expect(tester.takeException(), isNull);
      expect(find.text('83,5'), findsOneWidget);
      expect(find.text('Baik'), findsOneWidget);
      expect(find.text('Tim'), findsNothing);
      await tester.scrollUntilVisible(find.textContaining('Sanggah (sampai'), 300, scrollable: _vScroll);
      _expectTappableAt(tester, find.textContaining('Sanggah (sampai'));
      expect(find.text('Tidak menyapa pembeli (CCTV)'), findsOneWidget);
      expect(find.text('−0,4'), findsWidgets);
    });

    testWidgets('Skor KPI: KPI belum berlaku ditampilkan sebagai pesan, bukan galat', (tester) async {
      final repo = _Repo()..mineError = KpiNotActive('KPI belum berlaku untuk periode ini');
      await _pump(tester, const MyKpiPage(), repo);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('KPI belum berlaku untuk'), findsOneWidget);
      expect(find.text('Coba lagi'), findsNothing);
    });

    testWidgets('Skor KPI leader: tab Tim berisi leader & crew', (tester) async {
      final repo = _Repo()
        ..mineResult = MyKpi.fromJson({
          'period': '2026-11',
          'scores': [_score(), _score(module: 'LEADER', score: 91.25, events: [])],
        })
        ..teamResult = KpiTeam.fromJson({
          'period': '2026-11',
          'branch_id': 8,
          'branch_name': 'JUNTIKEDOKAN',
          'crew': [
            {'module': 'CREW', 'user_id': 7, 'name': 'Ilham', 'score': 83.5, 'predicate': 'Baik', 'status': 'running'},
            {'module': 'CREW', 'user_id': 9, 'name': 'Diyan', 'score': null, 'predicate': '', 'status': 'running'},
          ],
          'leaders': [
            {'module': 'LEADER', 'user_id': 11, 'name': 'Aenah', 'score': 91.25, 'predicate': 'Sangat Baik', 'status': 'running'},
          ],
        });
      await _pump(tester, const MyKpiPage(), repo, roles: const ['leader']);
      await tester.scrollUntilVisible(find.text('KPI Leader'), 300, scrollable: _vScroll);
      expect(find.text('KPI Leader'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('KPI Crew'), -300, scrollable: _vScroll);
      await tester.tap(find.text('Tim'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Aenah'), findsOneWidget);
      expect(find.text('Diyan'), findsOneWidget);
      expect(find.text('91,25'), findsWidgets);
      expect(find.textContaining('Hanya untuk dilihat'), findsOneWidget);
    });

    testWidgets('Sanggah: tombol kirim mati sampai alasan diisi', (tester) async {
      await _pump(tester, KpiDisputePage(event: KpiEvent.fromJson(_event())), _Repo());
      expect(tester.takeException(), isNull);
      final send = _button('Kirim sanggahan');
      expect(tester.widget<ButtonStyleButton>(send).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Saya bertugas penyaji hari itu');
      await tester.pump();
      _expectTappable(tester, 'Kirim sanggahan');
      _expectTappable(tester, 'Tambah foto');
    });

    testWidgets('Ceklis foto: Ambil foto, Foto ulang + alasan tolak, Belum dipakai; yang di-ACC tanpa tombol', (tester) async {
      final repo = _Repo()..checklist = [_set(phases: [
            _phase('opening', opens: _now.subtract(const Duration(hours: 1)), cutoff: _now.add(const Duration(hours: 6)), items: [
              _item(1, 'Area luar', 'approved'),
              _item(2, 'Menu', 'missing'),
              _item(3, 'Neon box bawah', 'rejected', reject: 'Buram'),
              _item(6, 'Serbet', 'missing', allowUnused: true),
            ]),
          ])];
      await _pump(tester, const PhotoChecklistPage(), repo);
      expect(tester.takeException(), isNull);
      expect(find.text('Opening (1/4)'), findsOneWidget);
      expect(find.text('Di-ACC'), findsOneWidget);
      expect(find.text('Terlambat'), findsOneWidget);
      expect(find.text('Ditolak: Buram'), findsOneWidget);
      _expectTappable(tester, 'Ambil foto');
      expect(_button('Ambil foto'), findsNWidgets(2)); // Menu, Serbet
      _expectTappable(tester, 'Foto ulang');
      _expectTappable(tester, 'Belum dipakai');
      expect(_button('Belum dipakai'), findsOneWidget);

      // "Belum dipakai" → alasan wajib → terkirim tanpa foto.
      await tester.ensureVisible(_button('Belum dipakai'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Belum dipakai'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Masih baru');
      await tester.pump();
      await tester.tap(_button('Kirim'));
      await tester.pumpAndSettle();
      expect(repo.submitted, ['1077:6:unused:Masih baru']);
    });

    testWidgets('Ceklis foto: fase belum dibuka tanpa tombol, jam bukanya tampil', (tester) async {
      final repo = _Repo()..checklist = [_set(phases: [
            _phase('closing', opens: _now.add(const Duration(hours: 2)), cutoff: _now.add(const Duration(hours: 9)), items: [
              _item(7, 'Laporan POS', 'missing'),
            ]),
          ])];
      await _pump(tester, const PhotoChecklistPage(), repo);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Dibuka pukul'), findsOneWidget);
      expect(_button('Ambil foto'), findsNothing);
    });

    testWidgets('Kartu Beranda: tampil bila ada foto perlu dikirim, hilang bila lengkap', (tester) async {
      final repo = _Repo()..checklist = [_set()];
      await _pump(tester, const Scaffold(body: Column(children: [PhotoChecklistCard()])), repo);
      expect(tester.takeException(), isNull);
      expect(find.text('1 foto ceklis ditolak, kirim ulang'), findsOneWidget);
      expect(find.textContaining('Menu'), findsOneWidget);

      final done = _Repo()..checklist = [_set(phases: [
            _phase('opening', opens: _now.subtract(const Duration(hours: 1)), cutoff: _now.add(const Duration(hours: 6)), items: [
              _item(1, 'Area luar', 'approved'),
            ]),
          ])];
      await _pump(tester, const Scaffold(body: Column(children: [PhotoChecklistCard()])), done);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('Kartu Beranda: tidak tampil untuk SPV', (tester) async {
      final repo = _Repo()..checklist = [_set()];
      await _pump(tester, const Scaffold(body: Column(children: [PhotoChecklistCard()])), repo,
          roles: const ['supervisor']);
      expect(find.textContaining('foto ceklis'), findsNothing);
    });

    testWidgets('Setoran: status, terlambat, ditolak + Kirim ulang', (tester) async {
      final repo = _Repo()
        ..deposits = [
          CashDeposit.fromJson({
            'id': 2,
            'operational_date': '2026-11-03T00:00:00+07:00',
            'leader_name': 'Aenah',
            'amount': '900000',
            'status': 'rejected',
            'rejected_by_name': 'Nende',
            'reject_reason': 'Nominal tidak sama dengan bukti',
            'transfer_at': _iso(_now),
          }),
          CashDeposit.fromJson({
            'id': 1,
            'operational_date': '2026-11-02',
            'amount': 1250000,
            'status': 'verified',
            'late': true,
            'verified_by_name': 'Nende',
          }),
        ];
      await _pump(tester, const CashDepositPage(), repo, roles: const ['leader']);
      expect(tester.takeException(), isNull);
      expect(find.text('Rp 900.000'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Terlambat'), findsOneWidget);
      expect(find.textContaining('Nominal tidak sama'), findsOneWidget);
      _expectTappable(tester, 'Kirim ulang');
    });

    testWidgets('Kirim setoran: tombol mati tanpa nominal & bukti; kirim ulang mengisi nominal', (tester) async {
      await _pump(tester, const CashDepositFormPage(), _Repo(), roles: const ['leader']);
      expect(tester.takeException(), isNull);
      expect(tester.widget<ButtonStyleButton>(_button('Kirim setoran')).onPressed, isNull);
      _expectTappable(tester, 'Tambah bukti');

      final retry = CashDeposit.fromJson({
        'id': 2,
        'operational_date': DateTime.now().toIso8601String().substring(0, 10),
        'amount': '900000',
        'status': 'rejected',
      });
      await _pump(tester, CashDepositFormPage(key: UniqueKey(), retry: retry), _Repo(), roles: const ['leader']);
      expect(find.text('900.000'), findsOneWidget);
    });

    testWidgets('Form sidak: langkah tampil, Kirim mati, "Sisanya sesuai" menjawab sekelompok', (tester) async {
      final repo = _Repo()
        ..items = const [
          InspectionItem(id: 1, group: 'L6.1A', name: 'Area depan'),
          InspectionItem(id: 2, group: 'L6.1A', name: 'Area samping'),
          InspectionItem(id: 30, group: 'info', name: 'Regulator gas'),
        ];
      await _pump(tester, const InspectionFormPage(), repo, roles: const ['supervisor'], extra: [
        branchListProvider.overrideWith((ref) async => const [
              BranchModel(id: 8, name: 'JUNTIKEDOKAN'),
              BranchModel(id: 12, name: 'JUNTIKEBON', latitude: -6.7, longitude: 108.5),
              BranchModel(id: 18, name: 'CANDI', status: 'disabled'),
            ]),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('1. Outlet'), findsOneWidget);
      await tester.scrollUntilVisible(_button('Kirim sidak'), 300, scrollable: _vScroll);
      expect(find.text('4. Checklist (0/3)'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(_button('Kirim sidak')).onPressed, isNull);
      expect(find.text('Pilih outlet dulu.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('1. Outlet'), -300, scrollable: _vScroll);

      // Outlet tanpa koordinat: diberi tahu sebelum checklist diisi.
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(find.text('CANDI'), findsNothing); // cabang nonaktif tidak ditawarkan
      await tester.tap(find.text('JUNTIKEDOKAN').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Koordinat outlet ini belum diatur'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Sisanya sesuai').first, 300, scrollable: _vScroll);
      await tester.tap(find.text('Sisanya sesuai').first);
      await tester.pumpAndSettle();
      expect(find.text('4. Checklist (2/3)'), findsOneWidget);
      await tester.ensureVisible(find.text('Tidak').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tidak').last);
      await tester.pumpAndSettle();
      expect(find.text('4. Checklist (3/3)'), findsOneWidget);
      expect(find.text('Foto temuan (opsional)'), findsOneWidget);
      // Semua dijawab, tapi koordinat outlet kosong: tetap tidak bisa dikirim.
      await tester.scrollUntilVisible(_button('Kirim sidak'), 300, scrollable: _vScroll);
      expect(find.text('Koordinat outlet belum diatur.'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(_button('Kirim sidak')).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hasil sidak: per kelompok, tidak dinilai ditandai', (tester) async {
      final repo = _Repo()
        ..inspectionRows = [
          Inspection.fromJson({
            'id': 4,
            'branch_id': 12,
            'branch_name': 'JUNTIKEBON',
            'inspector_name': 'Alena',
            'at': _iso(_now),
            'distance_meters': 23.4,
            'scored': false,
            'failed_count': 1,
            'notes': 'Lantai belakang basah',
            'results': [
              {'item_id': 1, 'group': 'L6.1A', 'item_name': 'Area depan', 'passed': true, 'note': ''},
              {'item_id': 2, 'group': 'L6.1A', 'item_name': 'Area belakang', 'passed': false, 'note': 'Basah'},
              {'item_id': 30, 'group': 'info', 'item_name': 'Taste test', 'passed': true, 'note': ''},
            ],
          }),
        ];
      await _pump(tester, const InspectionDetailPage(inspectionId: 4), repo, roles: const ['supervisor']);
      expect(tester.takeException(), isNull);
      expect(find.text('1 tidak sesuai'), findsOneWidget);
      expect(find.textContaining('Tidak dinilai'), findsOneWidget);
      expect(find.text('Kebersihan area'), findsOneWidget);
      expect(find.text('Informasi (tanpa poin)'), findsOneWidget);
      expect(find.text('Jarak dari outlet 23 m'), findsOneWidget);
    });
  });
}
