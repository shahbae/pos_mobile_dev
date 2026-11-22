import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/presentation/pages/shipments/shipment_detail_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

AttendanceModel _att({bool checkedOut = false}) => AttendanceModel.fromJson({
      'id': 1,
      'user_id': 3,
      'branch_id': 7,
      'attendance_date': '2026-10-17',
      'shift': 'shift_1',
      'check_in_at': '2026-10-17T07:00:00+07:00',
      if (checkedOut) 'check_out_at': '2026-10-17T15:05:00+07:00',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(
      fileName: '.env',
      isOptional: true,
      mergeWith: {'API_BASE_URL': 'http://localhost'},
    );
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  group('status absen (kunci Buka Shift)', () {
    // Revisi owner 21 Nov 2026: kunci layar absensi dibuang; status ini kini
    // hanya mengunci Buka Shift. Aturan siapa yang terkunci di
    // test/revisi_21nov_g1_test.dart.
    test('karyawan murni', () {
      expect(isCrewOnly({'kasir'}), isTrue);
      for (final r in ['owner', 'supervisor', 'leader', 'produksi', 'finance']) {
        expect(isCrewOnly({r}), isFalse, reason: r);
      }
    });

    test('status dari absensi hari ini', () {
      expect(gateStatusOf(null), AttendanceGateStatus.notCheckedIn);
      expect(gateStatusOf(_att()), AttendanceGateStatus.working);
      expect(gateStatusOf(_att(checkedOut: true)), AttendanceGateStatus.checkedOut);
    });
  });

  group('cadangan saat server tak terjangkau', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('status tersimpan hanya berlaku untuk tanggal yang sama', () async {
      await AttendanceGateCache.write('2026-10-17', AttendanceGateStatus.checkedOut);
      expect(await AttendanceGateCache.read('2026-10-17'), AttendanceGateStatus.checkedOut);
      expect(await AttendanceGateCache.read('2026-10-18'), isNull);
    });
  });

  group('shift & kiriman', () {
    test('pemilik shift terbaca dari cashier_id', () {
      final s = ShiftModel.fromJson({'id': 1, 'status': 'open', 'cashier_id': 3, 'opening_cash': 0, 'total_sales': 0});
      expect(s.isOpen, isTrue);
      expect(s.cashierId, 3);
    });

    test('kiriman membawa revisi & alasan ubah', () {
      final sh = Shipment.fromJson({
        'id': 3, 'branch_id': 7, 'stock_request_id': 5, 'status': 'shipped',
        'revision': 2, 'edit_reason': 'stok teh tipis', 'edited_at': '2026-10-17T09:00:00Z',
      });
      expect(sh.revision, 2);
      expect(sh.wasEdited, isTrue);
      expect(sh.editReason, 'stok teh tipis');

      final lama = Shipment.fromJson({'id': 3, 'branch_id': 7, 'stock_request_id': 5, 'status': 'shipped'});
      expect(lama.revision, 0);
      expect(lama.wasEdited, isFalse);
    });

    testWidgets('detail menampilkan bahwa isinya diubah gudang', (tester) async {
      final sh = Shipment(
        id: 3, branchId: 7, branchName: 'Cabang Sudirman', stockRequestId: 5,
        status: 'shipped', revision: 1, editReason: 'stok teh tipis',
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [shipmentDetailProvider(sh.id).overrideWith((ref) async => sh)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: ShipmentDetailPage(shipmentId: sh.id)),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('diubah gudang: stok teh tipis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
