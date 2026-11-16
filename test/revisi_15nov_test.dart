import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/branch_waste_model.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/models/stock_alerts_report_model.dart';
import 'package:pos_mobile/data/repositories/branch_waste_repository.dart';
import 'package:pos_mobile/data/repositories/kpi_repository.dart';
import 'package:pos_mobile/presentation/pages/kpi/photo_checklist_page.dart';
import 'package:pos_mobile/presentation/pages/reports/stock_alerts_report_page.dart';
import 'package:pos_mobile/presentation/pages/waste/waste_form_page.dart';
import 'package:pos_mobile/presentation/providers/branch_waste_provider.dart';
import 'package:pos_mobile/presentation/providers/daily_report_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Kontrak: be-pos docs/api-revisi-15nov-fe.md (langkah 1, 2, 3, 5).
// Layar diuji pada HP 360 × 800 dp dengan tema app (pelajaran 1 Nov 2026).

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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, [List<Override> overrides = const []]) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.lightTheme, home: home),
);

/// Daftar dibangun malas: yang di bawah layar belum ada sebelum digulir.
Future<void> _reveal(WidgetTester tester, Finder f, {double delta = 300}) =>
    tester.scrollUntilVisible(f, delta, scrollable: find.byType(Scrollable).first);

Finder _button(String text) =>
    find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

class _FakeKpi implements KpiRepository {
  DeepCleanSet deepClean = const DeepCleanSet();
  Object? submitError;
  final submitted = <int>[];

  @override
  Future<List<ChecklistSet>> myChecklist() async => const [];

  @override
  Future<DeepCleanSet> myDeepClean() async => deepClean;

  @override
  Future<void> submitDeepClean({required int itemId, required Uint8List photo}) async {
    if (submitError != null) throw submitError!;
    submitted.add(itemId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWaste implements BranchWasteRepository {
  Object? createError;
  final created = <Map<String, Object?>>[];
  List<BranchWasteItem> list = const [
    BranchWasteItem(itemType: 'material', id: 1, name: 'Sirup', unit: 'ml', qtyOnHand: 1000),
    BranchWasteItem(itemType: 'plastic', id: 4, name: 'Cup 16oz', unit: 'pcs', qtyOnHand: 40),
  ];

  @override
  Future<List<BranchWasteItem>> items() async => list;

  @override
  Future<BranchWasteRecord> create({
    required String itemType,
    required int itemId,
    required String qty,
    required String cause,
    String note = '',
    required Uint8List photo,
  }) async {
    if (createError != null) throw createError!;
    created.add({'type': itemType, 'id': itemId, 'qty': qty, 'cause': cause, 'note': note, 'photo': photo.length});
    return const BranchWasteRecord(id: 7, itemName: 'Sirup', unit: 'ml', qty: '250', value: '625');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('Sidak (langkah 1)', () {
    test('photo_required: bawaan wajib, hanya false eksplisit yang melepas', () {
      expect(InspectionItem.fromJson({'id': 1, 'group': 'L6.1A', 'name': 'Mixer'}).photoRequired, isTrue);
      expect(InspectionItem.fromJson({'id': 1, 'photo_required': true}).photoRequired, isTrue);
      expect(InspectionItem.fromJson({'id': 1, 'photo_required': false}).photoRequired, isFalse);
    });
  });

  group('Stok menipis (langkah 2)', () {
    final row = {
      'item_type': 'material', 'id': 1, 'name': 'Sirup', 'unit': 'ml', 'branch_id': 1, 'branch_name': 'Outlet A',
      'qty_on_hand': '1400.0000',
      'packs': [
        {'template_id': 3, 'name': 'Jerigen', 'base_qty': '1000.0000', 'whole': '1', 'remainder': '400.0000', 'exact': '1.4000'},
      ],
      'threshold_packs': '2.0000', 'threshold_pack_name': 'Jerigen', 'threshold_base': '2000.0000',
      'updated_at': '2026-11-15T20:00:00+07:00',
    };

    test('baris dibaca: stok dalam kemasan, batas dalam kemasan, satuan dasar sebagai pembanding', () {
      final r = StockAlertsRow.fromJson(row);
      expect(r.stockText, '1,4 Jerigen');
      expect(r.thresholdText, '2 Jerigen');
      expect(r.baseText, '1.400 ml');
      expect(r.typeLabel, 'Bahan');
      expect(r.branchName, 'Outlet A');
    });

    test('stok minus tampil dalam satuan dasar; tanpa updated_at tidak menjatuhkan layar', () {
      final r = StockAlertsRow.fromJson({
        ...row,
        'item_type': 'sedotan',
        'qty_on_hand': '-4.0000',
        'packs': [
          {'template_id': 3, 'name': 'Pak', 'base_qty': '50', 'whole': '0', 'remainder': '-4', 'exact': '0'},
        ],
        'updated_at': null,
      });
      expect(r.isNegative, isTrue);
      expect(r.stockText, '-4 ml');
      expect(r.typeLabel, 'Sedotan');
      expect(r.updatedAt, isNull);
    });

    test('jawaban tanpa packs dan baris bentuk lama tidak melempar', () {
      final d = StockAlertsData.fromJson({'threshold': 0, 'rows': [{'item_type': 'topping', 'id': 2, 'name': 'Boba', 'unit': 'gr', 'qty_on_hand': '300'}]});
      expect(d.rows.single.stockText, '300 gr');
      expect(StockAlertsData.fromJson({'threshold': 0, 'rows': null}).rows, isEmpty);
    });

    testWidgets('layar kosong menjelaskan bahwa batas belum diisi, tanpa "Stok ≤ 5"', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const StockAlertsReportPage(), [
        stockAlertsReportProvider.overrideWith((ref) async => const StockAlertsData(rows: [])),
      ]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Layar ini juga kosong bila batas stok belum diisi'), findsOneWidget);
      expect(find.textContaining('Stok ≤'), findsNothing);
      expect(find.textContaining('Threshold'), findsNothing);
    });

    testWidgets('layar berisi menulis "Stok: 1,4 Jerigen" dan batasnya', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const StockAlertsReportPage(), [
        stockAlertsReportProvider.overrideWith((ref) async => StockAlertsData.fromJson({'rows': [row]})),
      ]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Stok: 1,4 Jerigen'), findsOneWidget);
      expect(find.textContaining('Batas 2 Jerigen'), findsOneWidget);
      expect(find.text('Sirup'), findsOneWidget);
    });
  });

  group('Waste outlet (langkah 3)', () {
    test('akses: owner, leader, karyawan (kasir dan penyaji); bukan SPV, finance, produksi', () {
      expect(hasFeature('owner', AppFeature.branchWaste), isTrue);
      expect(hasFeature('leader', AppFeature.branchWaste), isTrue);
      expect(hasFeature('karyawan', AppFeature.branchWaste), isTrue);
      expect(hasFeature('supervisor', AppFeature.branchWaste), isFalse);
      expect(hasFeature('finance', AppFeature.branchWaste), isFalse);
      expect(hasFeature('produksi', AppFeature.branchWaste), isFalse);
      // Penyaji (tanpa menu kasir) tetap boleh mencatat waste.
      expect(featuresForToday('karyawan', const ['karyawan'], cashierDuty: false), contains(AppFeature.branchWaste));
    });

    test('jumlah: koma dan titik diterima, kosong atau sampah tidak', () {
      expect(parseWasteQty('1,5'), 1.5);
      expect(parseWasteQty(' 250 '), 250);
      expect(parseWasteQty(''), isNull);
      expect(parseWasteQty('abc'), isNull);
    });

    testWidgets('form: tombol mati sampai lengkap, melebihi stok ditolak di layar, kirim lewat konfirmasi', (tester) async {
      _phone(tester);
      ImagePickerPlatform.instance = _FakeCamera();
      final repo = _FakeWaste();
      await tester.pumpWidget(_app(const WasteFormPage(), [branchWasteRepositoryProvider.overrideWithValue(repo)]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _reveal(tester, find.text('Catat waste'));
      expect(tester.widget<ButtonStyleButton>(_button('Catat waste')).onPressed, isNull);
      await _reveal(tester, find.text('Ketuk untuk memilih'), delta: -300);

      // Barang dari daftar yang bisa dicari.
      await tester.tap(find.text('Ketuk untuk memilih'));
      await tester.pumpAndSettle();
      expect(find.text('Cup 16oz'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Cari barang'), 'sirup');
      await tester.pumpAndSettle();
      expect(find.text('Cup 16oz'), findsNothing);
      await tester.tap(find.text('Sirup'));
      await tester.pumpAndSettle();
      expect(find.text('Sirup · Bahan'), findsOneWidget);
      expect(find.textContaining('Stok outlet: 1.000 ml'), findsOneWidget);

      // Lebih dari stok: ditolak di layar sebelum server.
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah (ml)'), '1500');
      await tester.pump();
      expect(find.text('Melebihi stok outlet'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah (ml)'), '250,5');
      await tester.pump();
      expect(find.text('Melebihi stok outlet'), findsNothing);

      await _reveal(tester, find.text('Tumpah'));
      await tester.tap(find.text('Tumpah'));
      await tester.pump();
      // Foto belum ada → masih mati.
      await _reveal(tester, find.text('Catat waste'));
      expect(tester.widget<ButtonStyleButton>(_button('Catat waste')).onPressed, isNull);

      await _reveal(tester, find.text('Ambil foto'));
      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Catat waste'));
      expect(tester.widget<ButtonStyleButton>(_button('Catat waste')).onPressed, isNotNull);

      await tester.tap(_button('Catat waste'));
      await tester.pumpAndSettle();
      expect(find.text('Catat waste?'), findsOneWidget);
      await tester.tap(find.text('Catat'));
      await tester.pumpAndSettle();
      expect(repo.created, [
        {'type': 'material', 'id': 1, 'qty': '250.5', 'cause': 'Tumpah', 'note': '', 'photo': _png.length},
      ]);
    });

    testWidgets('form: pesan 422 server tampil apa adanya dan form tetap terisi', (tester) async {
      _phone(tester);
      ImagePickerPlatform.instance = _FakeCamera();
      final repo = _FakeWaste()
        ..createError = KpiApiError('stok Sirup di outlet ini kurang dari jumlah waste', code: 'branch_stock_not_enough', status: 422);
      await tester.pumpWidget(_app(const WasteFormPage(), [branchWasteRepositoryProvider.overrideWithValue(repo)]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ketuk untuk memilih'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sirup'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah (ml)'), '250');
      await _reveal(tester, find.text('Basi'));
      await tester.tap(find.text('Basi'));
      await tester.pump();
      await _reveal(tester, find.text('Ambil foto'));
      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Catat waste'));
      await tester.tap(_button('Catat waste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catat'));
      await tester.pumpAndSettle();
      // Pesan tampil di snackbar (pasti terlihat) dan di catatan di atas tombol.
      expect(find.text('stok Sirup di outlet ini kurang dari jumlah waste'), findsWidgets);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(WasteFormPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Deep cleaning (langkah 5)', () {
    final set = DeepCleanSet.fromJson({
      'branch_id': 1, 'branch_name': 'Outlet A',
      'week_start': '2026-11-16T00:00:00+07:00', 'week_end': '2026-11-22', 'deadline': '2026-11-22T23:59:59+07:00',
      'scored': false, 'total': 3, 'sent': 1, 'approved': 0,
      'items': [
        {'item_id': 4, 'name': 'Kulkas', 'status': 'pending', 'photo_url': null, 'uploaded_by_name': 'Rina', 'taken_at': '2026-11-17T09:00:00+07:00'},
        {'item_id': 5, 'name': 'Lantai dapur', 'status': 'missing'},
        {'item_id': 6, 'name': 'Rak topping', 'status': 'rejected', 'reject_reason': 'Foto buram'},
      ],
    });

    test('set dibaca; hanya pending dan approved yang dianggap terkirim', () {
      expect(set.weekStart, '2026-11-16');
      expect(set.scored, isFalse);
      expect([for (final i in set.items) i.isSent], [true, false, false]);
      expect(const DeepCleanSet().isEmpty, isTrue);
    });

    testWidgets('kartu: label belum dinilai KPI, yang terkirim tanpa tombol, ditolak boleh foto ulang', (tester) async {
      _phone(tester);
      final repo = _FakeKpi()..deepClean = set;
      await tester.pumpWidget(_app(const PhotoChecklistPage(), [kpiRepositoryProvider.overrideWithValue(repo)]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Deep cleaning mingguan'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Belum dinilai KPI'), findsOneWidget);
      expect(find.textContaining('Difoto 1/3'), findsOneWidget);
      expect(find.text('Ambil foto'), findsOneWidget); // Lantai dapur; Kulkas sudah terkirim
      expect(find.text('Foto ulang'), findsOneWidget); // Rak topping ditolak
      expect(find.text('Ditolak: Foto buram'), findsOneWidget);
    });

    testWidgets('memotret mengirim butirnya; 409 rekan sudah memfoto bukan galat', (tester) async {
      _phone(tester);
      ImagePickerPlatform.instance = _FakeCamera();
      final repo = _FakeKpi()..deepClean = set;
      await tester.pumpWidget(_app(const PhotoChecklistPage(), [kpiRepositoryProvider.overrideWithValue(repo)]));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Ambil foto'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();
      expect(repo.submitted, [5]);
      // Biarkan snackbar pertama hilang; ia menutupi tombol di bawahnya.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Foto ulang'));

      repo.submitError = KpiApiError('butir ini sudah difoto dan menunggu ACC', code: 'deep_clean_already_sent', status: 409);
      await tester.tap(find.text('Foto ulang'));
      await tester.pumpAndSettle();
      expect(find.text('Rak topping sudah difoto rekanmu minggu ini.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('master kosong: kartu menjelaskan, ceklis harian tidak terganggu', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const PhotoChecklistPage(), [kpiRepositoryProvider.overrideWithValue(_FakeKpi())]));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada ceklis foto untuk shiftmu hari ini.'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Belum ada butir deep cleaning'), 300, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  });
}
