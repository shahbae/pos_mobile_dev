import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/payroll_model.dart';
import 'package:pos_mobile/presentation/pages/payroll/cash_loan_page.dart';
import 'package:pos_mobile/presentation/pages/payroll/my_loans_page.dart';
import 'package:pos_mobile/presentation/pages/payroll/payroll_widgets.dart';
import 'package:pos_mobile/presentation/pages/payroll/payslip_detail_page.dart';
import 'package:pos_mobile/presentation/pages/payroll/payslip_list_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/payroll_provider.dart';
import 'package:pos_mobile/presentation/widgets/attendance_gate.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Tahap 2 SDM, langkah 4: slip gaji, pinjaman, komplain, dan serah pinjaman
/// tunai di app kasir. Bentuk JSON diambil dari docs/api-penggajian-fe.md.
///
/// Contoh orangnya: Diyan (karyawan, Karangampel) — gaji November Rp1.955.000
/// sesudah bonus dan potongan pinjaman.

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  Future<bool> refreshSession() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthState _auth(List<String> roles, {int? branchId = 2}) => AuthState(
      status: AuthStatus.authenticated,
      role: roles.first,
      roles: roles,
      branchId: branchId,
    );

Map<String, dynamic> _slipJson({List<Map<String, dynamic>> complaints = const []}) => {
      'id': 3,
      'period_id': 1,
      'user_id': 5,
      'user_name': 'Diyan',
      'position': 'Crew outlet',
      'location': 'Karangampel',
      'bank_name': 'SEA BANK',
      'bank_account': '901063888051',
      'joined_at': null,
      'left_at': null,
      'base_salary_missing': false,
      'total_earnings': '2075000',
      'total_deductions': '120000',
      'net_pay': '1955000',
      'carry_over': '0',
      'transferred_at': '2026-11-27T00:00:00+07:00',
      'payday': '2026-11-27',
      'period_from': '2026-10-27',
      'period_to': '2026-11-26',
      'period_status': 'approved',
      'earnings': [
        {
          'id': 11, 'payslip_id': 3, 'side': 'earning', 'kind': 'base_salary', 'label': 'Gaji pokok',
          'quantity': null, 'unit': '', 'rate': null, 'amount': '2000000', 'source': 'auto', 'note': '',
          'details': null,
        },
        {
          'id': 12, 'payslip_id': 3, 'side': 'earning', 'kind': 'bonus', 'label': 'Bonus',
          'quantity': null, 'unit': '', 'rate': null, 'amount': '75000', 'source': 'manual',
          'note': 'Penjualan terbaik minggu ini', 'details': null,
        },
      ],
      'deductions': [
        {
          'id': 13, 'payslip_id': 3, 'side': 'deduction', 'kind': 'late', 'label': 'Terlambat',
          'quantity': 2, 'unit': 'jam', 'rate': '10000', 'amount': '20000', 'source': 'auto', 'note': '',
          'details': [
            {'date': '2026-11-03', 'description': 'Shift 1, telat 1 jam 20 menit', 'quantity': 1},
            {'date': '2026-11-10', 'description': 'Shift 1, telat 45 menit', 'quantity': 1},
          ],
        },
        {
          'id': 14, 'payslip_id': 3, 'side': 'deduction', 'kind': 'loan', 'label': 'Pinjaman',
          'quantity': null, 'unit': '', 'rate': null, 'amount': '100000', 'source': 'auto',
          'note': 'Kebutuhan sehari-hari', 'loan_id': 2,
          'details': [
            {'date': '2026-10-27', 'description': 'Kebutuhan sehari-hari', 'amount': '100000'},
          ],
        },
      ],
      'complaints': complaints,
      'warnings': [],
    };

Map<String, dynamic> _loanJson({
  int id = 2,
  String status = 'requested',
  String? reason,
  String? method,
  String? branch,
  String? deduct,
  int? payslipId,
}) =>
    {
      'id': id,
      'user_id': 5,
      'user_name': 'Diyan',
      'amount': '100000',
      'purpose': 'Kebutuhan sehari-hari',
      'status': status,
      'requested_at': '2026-10-27T16:30:00+07:00',
      'approved_at': status == 'requested' ? null : '2026-10-27T17:00:00+07:00',
      'reject_reason': reason,
      'cancelled_at': null,
      'disburse_method': method,
      'disburse_branch_id': branch == null ? null : 2,
      'disburse_branch_name': branch,
      'disbursed_at': status == 'disbursed' ? '2026-10-28T09:00:00+07:00' : null,
      'expense_id': null,
      'deduct_payday': deduct,
      'payslip_id': payslipId,
      'photo_url': null,
    };

Widget _host(Widget page, {AuthState? auth, List<Override> extra = const []}) => ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FixedAuth(auth ?? _auth(['karyawan']))),
        ...extra,
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: page),
    );

/// Teks layar: "Rp 1.955.000" memakai spasi tak-putus dari intl.
Finder _rp(String digits) => find.textContaining(RegExp('Rp\\s$digits'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  group('jawaban server', () {
    test('slip terbaca utuh, tanggal tidak bergeser', () {
      final s = PayslipView.fromJson(_slipJson());
      expect(s.netPay, 1955000);
      expect(s.transferredAt, '2026-11-27');
      expect(s.earnings.map((l) => l.label), ['Gaji pokok', 'Bonus']);
      expect(s.earnings[1].manual, isTrue);
      final late = s.deductions.first;
      expect((late.quantity, late.unit, late.rate), (2, 'jam', 10000));
      expect(late.details.length, 2);
      expect(s.deductions[1].details.single.amount, 100000);
      expect(s.hasOpenComplaint, isFalse);
    });

    test('daftar slip dan pinjaman', () {
      final row = MyPayslipRow.fromJson({
        'id': 3, 'payday': '2026-11-27', 'period_from': '2026-10-27', 'period_to': '2026-11-26',
        'total_earnings': '2075000', 'total_deductions': '120000', 'net_pay': '1955000',
        'transferred_at': null, 'open_complaint': true,
      });
      expect((row.netPay, row.transferredAt, row.openComplaint), (1955000, null, true));
      final loan = LoanModel.fromJson(_loanJson(status: 'disbursed', method: 'cash_drawer', deduct: '2026-11-27'));
      expect(loan.methodLabel, 'Tunai dari laci outlet');
      expect(loan.deductPayday, '2026-11-27');
      expect(loan.cancellable, isFalse);
      expect(LoanModel.fromJson(_loanJson()).cancellable, isTrue);
    });
  });

  group('siapa boleh', () {
    test('slip & pinjaman: semua karyawan, bukan owner murni', () {
      expect(canUsePayroll({'owner'}), isFalse);
      for (final r in ['karyawan', 'kasir', 'leader', 'supervisor', 'finance', 'produksi', 'admin_produksi']) {
        expect(canUsePayroll({r}), isTrue, reason: r);
      }
      // Owner yang juga memegang role karyawan tetap punya slip.
      expect(canUsePayroll({'owner', 'karyawan'}), isTrue);
    });

    test('serah pinjaman tunai: owner, leader, kasir, karyawan', () {
      for (final r in ['owner', 'leader', 'kasir', 'karyawan']) {
        expect(canHandOutLoan({r}), isTrue, reason: r);
      }
      for (final r in ['supervisor', 'finance', 'produksi']) {
        expect(canHandOutLoan({r}), isFalse, reason: r);
      }
    });
  });

  group('halaman', () {
    testWidgets('Slip Gaji: gaji bersih, belum ditransfer, komplain menunggu', (tester) async {
      await tester.pumpWidget(_host(const PayslipListPage(), extra: [
        myPayslipsProvider.overrideWith((ref) async => [
              MyPayslipRow.fromJson({
                'id': 3, 'payday': '2026-11-27', 'period_from': '2026-10-27', 'period_to': '2026-11-26',
                'total_earnings': '2075000', 'total_deductions': '120000', 'net_pay': '1955000',
                'transferred_at': null, 'open_complaint': true,
              }),
            ]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Gaji November 2026'), findsOneWidget);
      expect(find.text('Absensi 27 Okt – 26 November 2026'), findsOneWidget);
      expect(_rp('1.955.000'), findsOneWidget);
      expect(find.text('Belum ditransfer'), findsOneWidget);
      expect(find.text('Komplain menunggu'), findsOneWidget);
    });

    testWidgets('rincian slip: baris, rincian telat, total, tombol komplain', (tester) async {
      await tester.pumpWidget(_host(const PayslipDetailPage(payslipId: 3), extra: [
        payslipProvider.overrideWith((ref, id) async => PayslipView.fromJson(_slipJson())),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('SEA BANK 901063888051'), findsOneWidget);
      expect(find.text('Ditransfer'), findsOneWidget);
      expect(find.text('27 November 2026'), findsOneWidget);
      expect(find.textContaining('2 jam ×'), findsOneWidget);
      expect(find.text('Penjualan terbaik minggu ini'), findsOneWidget);

      // Rincian telat tertutup sampai diketuk.
      await tester.ensureVisible(find.text('Rincian (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Shift 1, telat 45 menit'), findsNothing);
      await tester.tap(find.text('Rincian (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Shift 1, telat 45 menit'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Total diterima'), 200);
      expect(_rp('1.955.000'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Ada yang salah? Ajukan komplain'), 200);
      expect(find.text('Ada yang salah? Ajukan komplain'), findsOneWidget);
    });

    testWidgets('rincian slip dengan komplain terbuka: tidak bisa komplain lagi', (tester) async {
      await tester.pumpWidget(_host(const PayslipDetailPage(payslipId: 3), extra: [
        payslipProvider.overrideWith((ref, id) async => PayslipView.fromJson(_slipJson(complaints: [
              {
                'id': 1, 'payslip_id': 3, 'user_id': 5, 'message': 'Lembur 3 Nov belum masuk',
                'status': 'open', 'response': null, 'decided_by': null, 'decided_at': null,
                'created_at': '2026-11-27T10:00:00+07:00',
              },
            ]))),
      ]));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Lembur 3 Nov belum masuk'), 200);
      expect(find.text('Menunggu keputusan owner'), findsOneWidget);
      expect(find.text('Ada yang salah? Ajukan komplain'), findsNothing);
    });

    testWidgets('Pinjaman: status, alasan tolak, batal hanya untuk yang diajukan', (tester) async {
      await tester.pumpWidget(_host(const MyLoansPage(), extra: [
        myLoansProvider.overrideWith((ref) async => [
              LoanModel.fromJson(_loanJson(id: 4)),
              LoanModel.fromJson(_loanJson(id: 3, status: 'awaiting_cash', branch: 'Karangampel')),
              LoanModel.fromJson(_loanJson(id: 2, status: 'rejected', reason: 'Pinjaman lalu belum lunas')),
              LoanModel.fromJson(
                  _loanJson(id: 1, status: 'disbursed', method: 'transfer', deduct: '2026-11-27', payslipId: 3)),
            ]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Diajukan'), findsOneWidget);
      expect(find.text('Siap diambil di outlet'), findsOneWidget);
      expect(find.textContaining('Ambil tunai di kasir Karangampel'), findsOneWidget);
      expect(find.text('Alasan ditolak: Pinjaman lalu belum lunas'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sudah dipotong di gaji November 2026'), 200);
      expect(find.text('Sudah dipotong di gaji November 2026'), findsOneWidget);
      expect(find.text('Batalkan'), findsOneWidget);
      expect(find.text('Ajukan pinjaman'), findsOneWidget);
    });

    testWidgets('Ajukan pinjaman: Lanjut menyala setelah nominal & keperluan diisi', (tester) async {
      await tester.pumpWidget(_host(const MyLoansPage(), extra: [
        myLoansProvider.overrideWith((ref) async => const []),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajukan pinjaman'));
      await tester.pumpAndSettle();
      final lanjut = find.ancestor(of: find.text('Lanjut'), matching: find.byType(ElevatedButton));
      expect(tester.widget<ElevatedButton>(lanjut).onPressed, isNull);
      await tester.enterText(find.widgetWithText(TextField, 'Nominal'), '150000');
      await tester.enterText(find.widgetWithText(TextField, 'Untuk keperluan apa?'), 'Ongkos pulang');
      await tester.pump();
      expect(find.text('150.000'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(lanjut).onPressed, isNotNull);
    });

    testWidgets('Pinjaman Tunai: daftar yang menunggu di outlet ini', (tester) async {
      await tester.pumpWidget(_host(const CashLoanPage(), auth: _auth(['kasir']), extra: [
        cashPendingLoansProvider.overrideWith((ref) async => [
              LoanModel.fromJson(_loanJson(status: 'awaiting_cash', branch: 'Karangampel')),
            ]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Diyan'), findsOneWidget);
      expect(_rp('100.000'), findsOneWidget);
      expect(find.text('Serahkan & foto'), findsOneWidget);
    });

    testWidgets('Pinjaman Tunai tanpa cabang aktif: diminta memilih cabang', (tester) async {
      await tester.pumpWidget(_host(const CashLoanPage(), auth: _auth(['owner'], branchId: null)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pilih cabang aktif dulu'), findsOneWidget);
    });

    testWidgets('sesudah absen pulang: slip & pinjaman tetap bisa dibuka', (tester) async {
      await tester.pumpWidget(_host(const CheckedOutLockPage(), auth: _auth(['kasir'])));
      await tester.pumpAndSettle();
      expect(find.byType(PayrollMenuButton), findsOneWidget);
      await tester.tap(find.byType(PayrollMenuButton));
      await tester.pumpAndSettle();
      expect(find.text('Slip Gaji'), findsOneWidget);
      expect(find.text('Pinjaman'), findsOneWidget);
    });
  });
}
