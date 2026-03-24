import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final dashboardOperationalProvider = FutureProvider<DashboardOperationalData>((
  ref,
) async {
  final date = ref.watch(dashboardDateProvider);
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getOperational(date: date);
});
