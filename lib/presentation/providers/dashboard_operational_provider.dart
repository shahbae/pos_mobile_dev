import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/dashboard_operational_model.dart';
import 'package:pos_mobile/data/repositories/dashboard_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final api = ref.watch(apiProvider);
  return DashboardRepository(api);
});

final dashboardDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  return DateTimeRange(start: day, end: day);
});

final dashboardOperationalProvider = FutureProvider<DashboardOperationalData>((
  ref,
) async {
  final range = ref.watch(dashboardDateRangeProvider);
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getOperational(from: range.start, to: range.end);
});
