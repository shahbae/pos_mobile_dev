import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/expense_model.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/data/models/stock_pack_model.dart';
import 'package:pos_mobile/data/models/stock_request_model.dart';
import 'package:pos_mobile/data/repositories/kpi_repository.dart';
import 'package:pos_mobile/data/repositories/shipment_repository.dart';
import 'package:pos_mobile/data/repositories/stock_request_repository.dart';
import 'package:pos_mobile/presentation/pages/expenses/expense_form_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/pages/kpi/my_kpi_page.dart';
import 'package:pos_mobile/presentation/pages/shipments/shipment_complaint_page.dart';
import 'package:pos_mobile/presentation/pages/shipments/shipment_receive_page.dart';
import 'package:pos_mobile/presentation/pages/stock_requests/stock_request_form_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/expense_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_request_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Kontrak: be-pos docs/api-kpi-tahap7-fe.md (langkah 2 & 3).

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// Kamera palsu: selalu mengembalikan foto 1×1 dari memori.
class _FakeCamera extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(_png, name: 'foto.jpg', mimeType: 'image/jpeg');
}

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Scrollable halaman (bukan milik kotak isian, yang juga Scrollable).
Finder _page() => find.byType(Scrollable).first;

class _FakeShipments implements ShipmentRepository {
  List<ReceiveLineInput>? damage;
  int? revision;

  @override
  Future<void> receive(int id, {int? revision, List<ReceiveLineInput> lines = const []}) async {
    this.revision = revision;
    damage = lines.where((d) => d.hasDamage).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeKpi implements KpiRepository {
  Map<String, Object?>? complaint;

  @override
  Future<MyKpi> mine({String? period}) async => MyKpi.fromJson(_spvJson);

  @override
  Future<void> createQualityComplaint({
    required int shipmentId,
    required int branchId,
    required String content,
    required Uint8List photo,
    DateTime? occurredAt,
    String? itemType,
    int? itemId,
  }) async {
    complaint = {'shipment': shipmentId, 'branch': branchId, 'content': content, 'photo': photo.length, 'item': '$itemType:$itemId'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequests implements StockRequestRepository {
  DateTime? neededBy;

  @override
  Future<StockRequest> createRequest({String? note, DateTime? neededBy, required List<Map<String, dynamic>> items}) async {
    this.neededBy = neededBy;
    return StockRequest(id: 1, branchId: 12, requestedBy: 5, status: 'submitted');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Skor SPV Alena dari `GET /me/kpi`.
final _spvJson = {
  'period': '2026-11',
  'input_close_at': '2026-12-04T00:00:00+07:00',
  'scores': [
    {
      'period': '2026-11',
      'module': 'SPV',
      'user_id': 2,
      'name': 'Alena',
      'branch_id': 0,
      'branch_name': 'Pusat',
      'score': 72.5,
      'predicate': 'Cukup',
      'status': 'computed',
      'detail': {
        'score': 72.5,
        'pools': [
          {
            'code': 'SPV-B1',
            'name': 'Sidak outlet',
            'method': 'measure',
            'weight': 20,
            'score': 16.6667,
            'indicators': [
              {
                'code': 'SPV-B1',
                'name': 'Sidak mingguan sah',
                'rule_type': 'COUNT_TARGET',
                'value': 16.6667,
                'measure': {
                  'numerator': 10,
                  'denominator': 12,
                  'unit': 'minggu',
                  'outlets': [7, 8, 12],
                  'parts': [
                    {'branch_id': 7, 'done': 4, 'target': 4},
                  ],
                },
              },
            ],
          },
        ],
      },
      'events': [],
    },
  ],
};

ShipmentLine _sirup() => ShipmentLine(
  id: 31,
  itemType: 'material',
  itemId: 9,
  name: 'Sirup Leci',
  unit: 'ml',
  qty: 6000,
  pack: StockPack(templateId: 3, name: '1 botol', baseQty: 1000, whole: 6, exact: 6),
);

ShipmentLine _gula() => ShipmentLine(id: 32, itemType: 'material', itemId: 4, name: 'Gula', unit: 'gram', qty: 5000);

Shipment _shipment({String status = 'shipped'}) => Shipment(
  id: 77,
  branchId: 12,
  branchName: 'Juntikedokan',
  stockRequestId: 40,
  status: status,
  revision: 2,
  lines: [_sirup(), _gula()],
);

/// Ukuran HP sungguhan (411×914 dp), supaya tombol yang terdorong keluar
/// layar ikut tertangkap.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.lightTheme, home: home),
);

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('aturan', () {
    test('tenggat: bawaan besok 10.00, paling cepat 2 jam, dikirim UTC', () {
      final now = DateTime(2026, 11, 10, 15, 30);
      expect(defaultNeededBy(now), DateTime(2026, 11, 11, 10));
      expect(neededByProblem(now.add(const Duration(hours: 1)), now), isNotNull);
      expect(neededByProblem(DateTime(2026, 11, 11, 8), now), isNull);
      expect(neededByParam(DateTime.utc(2026, 11, 11, 3)), '2026-11-11T03:00:00.000Z');
      expect(neededByShortcuts(now).map((s) => s.$1), ['Besok 08.00', 'Besok 10.00', 'Besok 14.00', 'Lusa 10.00']);
      final r = StockRequest.fromJson({'id': 1, 'status': 'submitted', 'needed_by': '2026-11-11T10:00:00+07:00'});
      expect(r.neededBy, '2026-11-11T10:00:00+07:00');
    });

    test('rusak/kedaluwarsa diisi dalam kemasan, dikirim satuan dasar', () {
      final s = ReceiveLineInput(line: _sirup(), received: 6);
      expect(s.inputUnit, 'botol');
      expect(s.shippedInInput, 6);
      final d = s.copyWith(damaged: 2, expired: 0.5);
      expect(d.damagedBase, 2000);
      expect(d.expiredBase, 500);
      expect(d.acceptedBase, 3500);
      expect(d.needsPhoto, isTrue);
      expect(receiveProblems([d]).single, contains('ambil foto'));
      expect(receiveProblems([d.copyWith(photo: _png)]), isEmpty);
      expect(receiveProblems([s.copyWith(damaged: 7, photo: _png)]).single, contains('melebihi'));
      // Tanpa kemasan: satuan dasar apa adanya.
      final g = ReceiveLineInput(line: _gula()).copyWith(expired: 250);
      expect([g.inputUnit, g.expiredBase], ['gram', 250]);
      expect(receiveQtyParam(2000), '2000');
      expect(receiveQtyParam(0.33333333), '0.3333');
    });

    test('hasil terima dibaca dari server', () {
      final l = ShipmentLine.fromJson({
        'id': 31, 'item_type': 'material', 'item_id': 9, 'name': 'Sirup', 'unit': 'ml', 'qty': '6000',
        'damaged_qty': '2000', 'expired_qty': '0', 'damage_photo_url': 'https://x/y.jpg',
      });
      expect([l.damagedQty, l.expiredQty, l.hasDamage, l.damagePhotoUrl], [2000, 0, true, 'https://x/y.jpg']);
    });

    test('hak per role (Tahap 7)', () {
      // Alena (SPV), Khaerudien (leader), Admin (owner).
      expect(canSeeOwnKpi({'supervisor'}), isTrue);
      expect(canUsePhotoChecklist({'supervisor'}), isFalse);
      expect(canSeeOwnKpi({'owner'}), isFalse);
      expect(canComplainShipment({'leader'}), isTrue);
      expect(canComplainShipment({'supervisor'}), isFalse);
      expect(canComplainShipment({'karyawan'}), isFalse);
    });

    test('jenis biaya & skor SPV dibaca dari server', () {
      final types = [
        CostType.fromJson({'id': 1, 'name': 'Es kristal', 'sort': 1}),
        CostType.fromJson({'id': 7, 'name': 'Listrik', 'is_opex': true, 'is_active': false, 'sort': 7}),
      ];
      expect(costTypeName(types, 7), 'Listrik');
      expect(costTypeName(types, null), isNull);
      expect(types[1].isOpex && !types[1].isActive, isTrue);
      expect(ExpenseModelCost.parse({'cost_type_id': 3}), 3);

      final s = MyKpi.fromJson(_spvJson).scores.single;
      expect(kpiModuleLabels[s.module], 'SPV');
      final m = s.detail!.pools.single.indicators.single.measure!;
      expect([m.numerator, m.denominator, m.unit], [10, 12, 'minggu']);
      expect(kpiMeasureText(m), '10 dari 12 minggu');
      expect(kpiMeasureText(const KpiMeasure(numerator: 496.1174, denominator: 6, unit: 'leader')),
          'rata-rata 82,69 dari 6 leader');
      expect(kpiMeasureText(const KpiMeasure(numerator: 13000000, denominator: 15000000, unit: 'Rp')),
          'Rp 13.000.000 dari Rp 15.000.000');
    });
  });

  group('layar (tema app, ukuran HP)', () {
    testWidgets('Terima kiriman: rusak wajib foto, lalu terkirim dalam satuan dasar', (tester) async {
      _phone(tester);
      ImagePickerPlatform.instance = _FakeCamera();
      final repo = _FakeShipments();
      bool? popped;
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => popped = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => ShipmentReceivePage(shipment: _shipment())),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
        [shipmentRepositoryProvider.overrideWithValue(repo)],
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('Dikirim 6 botol (6.000 ml)'), findsOneWidget);
      // Revisi KPI 11 Nov: jumlah diterima wajib diketik tiap barang.
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah diterima').at(0), '6');
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah diterima').at(1), '5000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada rusak?').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Rusak'), '2');
      await tester.pumpAndSettle();
      expect(find.text('Masuk stok 4.000 ml'), findsOneWidget);

      await tester.tap(find.text('Terima Kiriman'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ambil foto'), findsOneWidget);
      expect(repo.damage, isNull, reason: 'belum terkirim tanpa foto');

      await tester.tap(find.text('Foto barang yang rusak (wajib)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terima Kiriman'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TIDAK masuk stok'), findsOneWidget);
      await tester.tap(find.text('Ya, terima'));
      await tester.pumpAndSettle();

      expect(repo.revision, 2);
      final d = repo.damage!.single;
      expect([d.line.id, d.damagedBase, d.expiredBase, d.photo?.length], [31, 2000, 0, _png.length]);
      expect(popped, isTrue);
    });

    testWidgets('Komplain kualitas: isi + foto wajib, terkirim dengan kiriman & outlet', (tester) async {
      _phone(tester);
      ImagePickerPlatform.instance = _FakeCamera();
      final kpi = _FakeKpi();
      await tester.pumpWidget(_app(
        ShipmentComplaintPage(shipment: _shipment(status: 'received')),
        [kpiRepositoryProvider.overrideWithValue(kpi)],
      ));
      await tester.pumpAndSettle();

      ElevatedButton send() => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Kirim komplain'));
      expect(send().onPressed, isNull);
      // Revisi KPI 11 Nov (PRD-C1): barangnya wajib dipilih.
      await tester.tap(find.text('Sirup Leci'));
      await tester.enterText(find.byType(TextField), 'Teh dari jerigen ini terasa asam');
      await tester.pumpAndSettle();
      expect(send().onPressed, isNull, reason: 'foto belum ada');
      await tester.scrollUntilVisible(find.text('Ambil foto'), 200, scrollable: _page());
      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Kirim komplain'), 200, scrollable: _page());
      await tester.tap(find.text('Kirim komplain'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, kirim'));
      await tester.pumpAndSettle();

      expect(kpi.complaint, {
        'shipment': 77,
        'branch': 12,
        'content': 'Teh dari jerigen ini terasa asam',
        'photo': _png.length,
        'item': 'material:9',
      });
    });

    testWidgets('Minta stok: tenggat bawaan besok 10.00 ikut terkirim', (tester) async {
      _phone(tester);
      final repo = _FakeRequests();
      await tester.pumpWidget(_app(const StockRequestFormPage(), [
        requestableItemsProvider.overrideWith((ref) async => [
          RequestableItem(
            itemType: 'material',
            itemId: 33,
            name: 'Teh Original',
            unit: 'ml',
            warehouseQty: 20000,
            templates: [RequestableTemplate(id: 330, name: 'Pack', baseQty: 5000)],
          ),
        ]),
        stockRequestRepositoryProvider.overrideWithValue(repo),
      ]));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '2');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Dibutuhkan paling lambat'), 200, scrollable: _page());
      final tomorrow10 = defaultNeededBy(DateTime.now());
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Besok 10.00')).selected, isTrue);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Besok 08.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajukan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('dibutuhkan paling lambat'), findsOneWidget);
      await tester.tap(find.text('Ya, kirim'));
      await tester.pumpAndSettle();

      expect(repo.neededBy, DateTime(tomorrow10.year, tomorrow10.month, tomorrow10.day, 8));
    });

    testWidgets('Skor KPI SPV: modul SPV, catatan nilai, dan ukuran', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const MyKpiPage(period: '2026-11'), [
        kpiRepositoryProvider.overrideWithValue(_FakeKpi()),
        authProvider.overrideWith((ref) => _FixedAuth(
              AuthState(status: AuthStatus.authenticated, role: 'supervisor', roles: const ['supervisor']),
            )),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('KPI SPV'), findsOneWidget);
      expect(find.text('72,5'), findsOneWidget);
      expect(find.textContaining('sama untuk semua SPV'), findsOneWidget);
      await tester.tap(find.text('SPV-B1 Sidak outlet'));
      await tester.pumpAndSettle();
      expect(find.text('10 dari 12 minggu'), findsOneWidget);
    });

    testWidgets('Catat pengeluaran: jenis biaya wajib dipilih', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const ExpenseFormPage(), [
        costTypesProvider.overrideWith((ref) async => const [
          CostType(id: 1, name: 'Es kristal', sort: 1),
          CostType(id: 2, name: 'Air galon', sort: 2),
          CostType(id: 9, name: 'Lama', isActive: false, sort: 9),
        ]),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Jenis Biaya *'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '25000');
      await tester.scrollUntilVisible(find.text('Simpan Pengeluaran'), 300, scrollable: _page());
      await tester.tap(find.text('Simpan Pengeluaran'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('cost-type-field')), -300, scrollable: _page());
      expect(find.text('Pilih jenis biaya'), findsWidgets);

      // Jenis nonaktif tidak ditawarkan.
      await tester.tap(find.byKey(const ValueKey('cost-type-field')));
      await tester.pumpAndSettle();
      expect(find.text('Air galon').last, findsOneWidget);
      expect(find.text('Lama'), findsNothing);
    });
  });
}

/// Membaca `cost_type_id` lewat [ExpenseModel.fromJson].
extension ExpenseModelCost on ExpenseModel {
  static int? parse(Map<String, dynamic> j) => ExpenseModel.fromJson(j).costTypeId;
}
