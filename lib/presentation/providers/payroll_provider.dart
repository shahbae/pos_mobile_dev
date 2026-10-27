import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/payroll_model.dart';
import 'package:pos_mobile/data/repositories/payroll_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  // Pinjaman tunai dibaca per cabang token; ikut lahir ulang saat pindah
  // cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return PayrollRepository(ref.watch(apiProvider));
});

/// Slip yang sudah terbit (periode disetujui owner), terbaru dulu.
final myPayslipsProvider = FutureProvider.autoDispose<List<MyPayslipRow>>((ref) {
  return ref.watch(payrollRepositoryProvider).myPayslips();
});

final payslipProvider = FutureProvider.autoDispose.family<PayslipView, int>((ref, id) {
  return ref.watch(payrollRepositoryProvider).payslip(id);
});

/// Pinjaman sendiri, terbaru dulu.
final myLoansProvider = FutureProvider.autoDispose<List<LoanModel>>((ref) {
  return ref.watch(payrollRepositoryProvider).myLoans();
});

/// Pinjaman tunai yang menunggu diserahkan dari laci cabang ini.
final cashPendingLoansProvider = FutureProvider.autoDispose<List<LoanModel>>((ref) {
  return ref.watch(payrollRepositoryProvider).cashPending();
});
