import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/leave_out_model.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/data/models/profile_model.dart';
import 'package:pos_mobile/data/models/schedule_model.dart';
import 'package:pos_mobile/data/repositories/attendance_repository.dart';
import 'package:pos_mobile/data/repositories/profile_repository.dart';
import 'package:pos_mobile/data/repositories/schedule_repository.dart';
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

/// Hari saya (Tahap 1 SDM): shift hari ini, absen hari ini, apakah masih ada
/// shift. Sumber halaman Absensi, kunci aplikasi, dan tugas kasir/penyaji.
/// Dibaca ulang lewat [refreshMyDay] sesudah absen dan saat app kembali ke depan.
final myDayProvider = FutureProvider<MyDay>((ref) async {
  return ref.watch(attendanceRepositoryProvider).getMyDay();
});

/// Baca ulang hari saya beserta semua turunannya (kunci app, tugas, izin keluar).
void refreshMyDay(WidgetRef ref) {
  ref.invalidate(myDayProvider);
  ref.invalidate(onDutyProvider);
}

/// Yang sedang bertugas di cabang token. Owner/SPV boleh memilih cabang.
final onDutyProvider =
    FutureProvider.autoDispose.family<List<OnDutyModel>, int?>((ref, branchId) {
  return ref.watch(attendanceRepositoryProvider).onDuty(branchId: branchId);
});

/// Izin keluar 7 hari terakhir (bawaan server). [branchId] untuk owner/SPV.
final leaveOutsProvider =
    FutureProvider.autoDispose.family<List<LeaveOutModel>, int?>((ref, branchId) {
  return ref.watch(attendanceRepositoryProvider).listLeaveOuts(branchId: branchId);
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(apiProvider));
});

/// Jadwal saya: awal bulan ini sampai akhir bulan depan (bawaan server).
final mySchedulesProvider = FutureProvider.autoDispose<List<MyScheduleEntry>>((ref) {
  return ref.watch(scheduleRepositoryProvider).getMine();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiProvider));
});

final myProfileProvider = FutureProvider.autoDispose<ProfileModel>((ref) {
  return ref.watch(profileRepositoryProvider).getMine();
});
