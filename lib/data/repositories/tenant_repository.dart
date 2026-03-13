import 'package:dio/dio.dart';
import 'package:pos_mobile/data/models/tenant_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';

class TenantRepository {
  final ApiService api;

  TenantRepository(this.api);

  Future<TenantModel> getMyTenant() async {
    try {
      final res = await api.dio.get('/me/tenant');

      if (res.statusCode != 200 || res.data['success'] != true) {
        final msg = res.data['message'] ?? 'Gagal mengambil data tenant';
        throw msg;
      }

      return TenantModel.fromJson(res.data['data']);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw msg ?? 'Gagal mengambil data tenant';
    } catch (e) {
      throw e.toString();
    }
  }
}
