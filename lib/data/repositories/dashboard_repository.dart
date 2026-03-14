import 'package:intl/intl.dart';
import 'package:pos_mobile/data/models/dashboard_operational_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';

class DashboardRepository {
  final ApiService api;

  DashboardRepository(this.api);

  Future<DashboardOperationalData> getOperational({
    required DateTime from,
    required DateTime to,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final res = await api.dio.get(
      '/dashboard/operational',
      queryParameters: {'from': fmt.format(from), 'to': fmt.format(to)},
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
