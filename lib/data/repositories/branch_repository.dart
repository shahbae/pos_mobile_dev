import 'package:dio/dio.dart';
import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/data/models/qris_payment_model.dart';
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

  Future<void> createBranch(Map<String, dynamic> data) async {
    try {
      final res = await api.dio.post('/branches', data: data);
      if (res.data is Map && res.data['success'] == false) {
        throw res.data['message'] ?? 'Gagal menambah cabang';
      }
    } on DioException catch (e) {
      throw e.response?.data?['message'] ?? 'Gagal menambah cabang';
    }
  }

  Future<void> updateBranch(int id, Map<String, dynamic> data) async {
    try {
      final res = await api.dio.put('/branches/$id', data: data);
      if (res.data is Map && res.data['success'] == false) {
        throw res.data['message'] ?? 'Gagal memperbarui cabang';
      }
    } on DioException catch (e) {
      throw e.response?.data?['message'] ?? 'Gagal memperbarui cabang';
    }
  }

  /// Setting QRIS cabang (docs/api-qris-manual-fe.md §5) — owner/supervisor.
  Future<QrisBranchConfig> getQrisConfig(int branchId) async {
    try {
      final res = await api.dio.get('/branches/$branchId/qris');
      final data = res.data['data'];
      if (data is! Map) throw 'Setting QRIS cabang tidak ditemukan';
      return QrisBranchConfig.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _qrisError(e, 'Gagal mengambil setting QRIS cabang');
    }
  }

  /// Simpan mode dan/atau payload QR statis. Field yang null tidak dikirim
  /// (BE membiarkan nilai lama).
  Future<QrisBranchConfig> saveQrisConfig(
    int branchId, {
    String? mode,
    String? payload,
  }) async {
    try {
      final body = <String, dynamic>{
        if (mode != null) 'mode': mode,
        if (payload != null) 'payload': payload,
      };
      final res = await api.dio.put('/branches/$branchId/qris', data: body);
      final data = res.data['data'];
      if (data is! Map) throw 'Respons setting QRIS tidak dikenali';
      return QrisBranchConfig.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _qrisError(e, 'Gagal menyimpan setting QRIS cabang');
    }
  }

  /// Hapus payload & kembalikan cabang ke mode default server.
  /// Ditolak BE bila cabang masih di mode `manual`.
  Future<void> deleteQrisConfig(int branchId) async {
    try {
      await api.dio.delete('/branches/$branchId/qris');
    } on DioException catch (e) {
      throw _qrisError(e, 'Gagal menghapus setting QRIS cabang');
    }
  }

  /// Pesan validasi QRIS dari BE sudah berbahasa Indonesia — teruskan apa adanya.
  String _qrisError(DioException e, String fallback) {
    final data = e.response?.data;
    final raw = (data is Map) ? (data['message'] ?? data['error']) : null;
    final msg = raw?.toString().trim();
    return (msg == null || msg.isEmpty) ? fallback : msg;
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
