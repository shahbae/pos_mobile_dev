import 'package:intl/intl.dart';
import 'package:pos_mobile/data/models/dashboard_model.dart';
import 'package:pos_mobile/data/models/dashboard_operational_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';

class DashboardRepository {
  final ApiService api;

  DashboardRepository(this.api);

  /// Dashboard adaptif per-role (revisi BE 2026-06-29).
  /// GET /dashboard?from=YYYY-MM-DD&to=YYYY-MM-DD (rentang opsional, default hari ini).
  Future<DashboardData> getDashboard({DateTime? from, DateTime? to}) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final res = await api.dio.get(
      '/dashboard',
      queryParameters: {
        if (from != null) 'from': fmt.format(from),
        if (to != null) 'to': fmt.format(to),
      },
    );

    if (res.statusCode != 200 || res.data['success'] != true) {
      final msg = res.data['message'] ??
          res.data['error'] ??
          'Gagal mengambil dashboard';
      throw msg;
    }

    final data = (res.data['data'] as Map).cast<String, dynamic>();
    return DashboardData.fromJson(data);
  }

  Future<DashboardOperationalData> getOperational({
    required DateTime date,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final res = await api.dio.get(
      '/dashboard/operational',
      queryParameters: {'date': fmt.format(date)},
    );

    if (res.statusCode != 200 || res.data['success'] != true) {
      final msg =
          res.data['message'] ??
          res.data['error'] ??
          'Gagal mengambil dashboard operasional';
      throw msg;
    }

    final data = (res.data['data'] as Map).cast<String, dynamic>();
    return DashboardOperationalData.fromJson(data);
  }
}
