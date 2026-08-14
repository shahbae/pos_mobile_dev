import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/repositories/attendance_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return AttendanceRepository(ref.watch(apiProvider));
});

/// Status absensi hari ini (self). `null` = belum check-in.
/// autoDispose agar selalu segar tiap halaman absensi dibuka.
final attendanceTodayProvider =
    FutureProvider.autoDispose<AttendanceModel?>((ref) async {
  return ref.watch(attendanceRepositoryProvider).getToday();
});
