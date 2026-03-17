import 'package:intl/intl.dart';
import 'package:pos_mobile/data/models/daily_report_model.dart';
import 'package:pos_mobile/data/models/profit_report_model.dart';
import 'package:pos_mobile/data/models/stock_alerts_report_model.dart';
import 'package:pos_mobile/data/models/top_products_report_model.dart';
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

  Future<ProfitReportData> getProfitReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    final res = await api.dio.get(
      '/reports/profit',
      queryParameters: {'from': fmt.format(fromDay), 'to': fmt.format(toDay)},
    );

    if (res.statusCode != 200 || res.data['success'] != true) {
      final msg =
          res.data['message'] ??
          res.data['error'] ??
          'Gagal mengambil laporan profit';
      throw msg;
    }

    final data = (res.data['data'] as Map).cast<String, dynamic>();
    return ProfitReportData.fromJson(data);
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

  Future<TopProductsData> getTopProductsReport({
    required DateTime from,
    required DateTime to,
    required int limit,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    final res = await api.dio.get(
      '/reports/top-products',
      queryParameters: {
        'from': fmt.format(fromDay),
        'to': fmt.format(toDay),
        'limit': limit,
      },
    );

    if (res.statusCode != 200 || res.data['success'] != true) {
      final msg =
          res.data['message'] ??
          res.data['error'] ??
          'Gagal mengambil laporan produk terlaris';
      throw msg;
    }

    final data = (res.data['data'] as Map).cast<String, dynamic>();
    return TopProductsData.fromJson(data);
  }
}
