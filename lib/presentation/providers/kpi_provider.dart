import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/repositories/kpi_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final kpiRepositoryProvider = Provider<KpiRepository>((ref) {
  return KpiRepository(ref.watch(apiProvider));
});

/// Skor sendiri per periode `YYYY-MM`.
final myKpiProvider = FutureProvider.autoDispose.family<MyKpi, String>((ref, period) {
  return ref.watch(kpiRepositoryProvider).mine(period: period);
});

/// Skor tim outlet (leader).
final kpiTeamProvider = FutureProvider.autoDispose.family<KpiTeam, String>((ref, period) {
  return ref.watch(kpiRepositoryProvider).team(period: period);
});

/// Ceklis foto shift hari ini. Tidak autoDispose: kartu Beranda dan
/// pengingat Tutup Shift membacanya bergantian.
final myChecklistProvider = FutureProvider<List<ChecklistSet>>((ref) {
  return ref.watch(kpiRepositoryProvider).myChecklist();
});

final cashDepositsProvider = FutureProvider.autoDispose<List<CashDeposit>>((ref) {
  return ref.watch(kpiRepositoryProvider).cashDeposits();
});

final inspectionItemsProvider = FutureProvider.autoDispose<List<InspectionItem>>((ref) {
  return ref.watch(kpiRepositoryProvider).inspectionItems();
});

final inspectionsProvider = FutureProvider.autoDispose<List<Inspection>>((ref) {
  return ref.watch(kpiRepositoryProvider).inspections();
});
