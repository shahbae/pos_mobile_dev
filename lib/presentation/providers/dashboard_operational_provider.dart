import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/dashboard_model.dart';
import 'package:pos_mobile/data/models/dashboard_operational_model.dart';
import 'package:pos_mobile/data/repositories/dashboard_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final api = ref.watch(apiProvider);
  return DashboardRepository(api);
});

final dashboardDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// autoDispose: angka operasional basi begitu ada transaksi masuk, jadi cache
/// hanya boleh hidup selama Beranda dibuka — pindah tab lalu kembali = data baru.
final dashboardOperationalProvider =
    FutureProvider.autoDispose<DashboardOperationalData>((ref) async {
  final date = ref.watch(dashboardDateProvider);
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getOperational(date: date);
});

/// Dashboard adaptif per-role (GET /dashboard, revisi BE 2026-06-29).
/// Rentang = dashboardDateProvider (default hari ini, from=to).
/// autoDispose dengan alasan yang sama seperti [dashboardOperationalProvider].
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final date = ref.watch(dashboardDateProvider);
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getDashboard(from: date, to: date);
});
