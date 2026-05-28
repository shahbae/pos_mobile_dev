import 'package:dio/dio.dart';
import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/data/services/secure_storage.dart';

class BranchRepository {
  final ApiService api;

  BranchRepository(this.api);

  Future<List<BranchModel>> getBranches() async {
    try {
      final res = await api.dio.get('/branches');
      if (res.statusCode != 200 || res.data['success'] != true) {
        throw res.data['message'] ?? 'Gagal mengambil daftar cabang';
      }
      final list = res.data['data'] as List;
      return list.map((e) => BranchModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw e.response?.data?['message'] ?? 'Gagal mengambil daftar cabang';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> switchBranch(int branchId) async {
    try {
      final res = await api.dio.post(
        '/auth/switch-branch',
        data: {'branch_id': branchId},
      );
      if (res.statusCode != 200 || res.data['success'] != true) {
        throw res.data['message'] ?? 'Gagal berpindah cabang';
      }
      final token = res.data['data']['access_token'] as String;
      await SecureStorage.saveTokens(accessToken: token);
    } on DioException catch (e) {
      throw e.response?.data?['message'] ?? 'Gagal berpindah cabang';
    } catch (e) {
      throw e.toString();
    }
  }
}
