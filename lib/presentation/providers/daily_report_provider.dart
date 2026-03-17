import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/daily_report_model.dart';
import 'package:pos_mobile/data/models/profit_report_model.dart';
import 'package:pos_mobile/data/models/stock_alerts_report_model.dart';
import 'package:pos_mobile/data/repositories/report_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final api = ref.watch(apiProvider);
  return ReportRepository(api);
});

final dailyReportDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final dailyReportProvider = FutureProvider<DailyReportData>((ref) async {
  final date = ref.watch(dailyReportDateProvider);
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getDailyReport(date: date);
});

final profitReportRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  return DateTimeRange(start: day, end: day);
});

final profitReportProvider = FutureProvider<ProfitReportData>((ref) async {
  final range = ref.watch(profitReportRangeProvider);
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getProfitReport(from: range.start, to: range.end);
});

final stockAlertsReportProvider = FutureProvider<StockAlertsData>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getStockAlertsReport();
});
