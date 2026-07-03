import 'package:intl/intl.dart';
import 'package:pos_mobile/data/models/daily_report_model.dart';
import 'package:pos_mobile/data/models/leader_daily_report_model.dart';
import 'package:pos_mobile/data/models/payments_report_model.dart';
import 'package:pos_mobile/data/models/stock_alerts_report_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';

class ReportRepository {
  final ApiService api;

  ReportRepository(this.api);

  Future<DailyReportData> getDailyReport({required DateTime date}) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final res = await api.dio.get(
      '/reports/daily',
      queryParameters: {'date': fmt.format(date)},
    );

    if (res.statusCode != 200 || res.data['success'] != true) {
      final msg =
          res.data['message'] ??
          res.data['error'] ??
          'Gagal mengambil laporan harian';
      throw msg;
    }

    final data = (res.data['data'] as Map).cast<String, dynamic>();
    return DailyReportData.fromJson(data);
  }

  /// Laporan harian leader — rekap 1 hari dipecah per shift (Shift 1 & 2).
  /// Branch-scoped via token; owner boleh melewatkan [branchId] opsional.
  Future<LeaderDailyReport> getLeaderDailyReport({
    required DateTime date,
    int? branchId,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final res = await api.dio.get(
      '/reports/leader/daily',
      queryParameters: {
        'date': fmt.format(date),
        if (branchId != null) 'branch_id': branchId,
      },
    );

    if (res.statusCode != 200 || res.data['success'] != true) {
      final msg =
          res.data['message'] ??
          res.data['error'] ??
          'Gagal mengambil laporan harian leader';
      throw msg;
    }

    final data = (res.data['data'] as Map).cast<String, dynamic>();
    return LeaderDailyReport.fromJson(data);
  }

  Future<StockAlertsData> getStockAlertsReport() async {
    final res = await api.dio.get('/reports/stock-alerts');

    if (res.statusCode != 200 || res.data['success'] != true) {
      final msg =
          res.data['message'] ??
          res.data['error'] ??
          'Gagal mengambil laporan stok menipis';
      throw msg;
    }

    final data = (res.data['data'] as Map).cast<String, dynamic>();
    return StockAlertsData.fromJson(data);
  }

  Future<PaymentsReportData> getPaymentsReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final fromDay = DateTime(from.year, from.month, from.day);
    // BE memfilter tanggal dalam WIB dengan `to` INKLUSIF, jadi kirim apa adanya
    // (tanpa +1 hari) supaya tidak ikut menarik transaksi besok.
    final toDay = DateTime(to.year, to.month, to.day);

    final res = await api.dio.get(
      '/reports/payments',
      queryParameters: {
        'from': fmt.format(fromDay),
        'to': fmt.format(toDay),
      },
    );

    if (res.statusCode != 200 || res.data['success'] != true) {
      final msg =
          res.data['message'] ??
          res.data['error'] ??
          'Gagal mengambil laporan pembayaran';
      throw msg;
    }

    final data = (res.data['data'] as Map).cast<String, dynamic>();
    return PaymentsReportData.fromJson(data);
  }
}
