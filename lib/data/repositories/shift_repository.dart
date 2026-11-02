import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return ShiftRepository(ref.watch(apiProvider));
});

/// Shift 2 ditolak ditutup karena opname harian hari itu belum lengkap
/// (Tahap 5 — 422 daily_audit_required).
class DailyAuditRequired implements Exception {
  final String message;
  DailyAuditRequired(this.message);
  @override
  String toString() => message;
}

class ShiftRepository {
  final ApiService api;
  ShiftRepository(this.api);

  /// Shift yang sedang aktif. null jika belum ada shift terbuka.
  Future<ShiftModel?> getCurrent() async {
    try {
      final res = await api.dio.get('/shifts/current');
      final data = res.data is Map ? res.data['data'] ?? res.data : res.data;
      if (data == null) return null;
      return ShiftModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Tidak ada shift aktif → backend bisa balas 404.
      if (e.response?.statusCode == 404) return null;
      throw e.response?.data?['message'] ?? 'Gagal memuat shift aktif';
    }
  }

  /// Buka shift. Uang laci (opening_cash) di-set backend dari master cabang,
  /// kasir tidak bisa meng-override, jadi FE tidak mengirim opening_cash.
  Future<ShiftModel> open() async {
    try {
      final res = await api.dio.post('/shifts', data: <String, dynamic>{});
      return ShiftModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.response?.data?['message'] ?? 'Gagal membuka shift';
    }
  }

  Future<ShiftModel> closeCurrent(num closingCash) async {
    try {
      final res = await api.dio.put('/shifts/current/close', data: {'closing_cash': closingCash});
      return ShiftModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['code'] == 'daily_audit_required') {
        throw DailyAuditRequired('${data['message'] ?? 'Buat opname harian dulu sebelum menutup Shift 2.'}');
      }
      throw e.response?.data?['message'] ?? 'Gagal menutup shift';
    }
  }

  Future<List<ShiftModel>> list({int page = 1, int limit = 20}) async {
    try {
      final res = await api.dio.get('/shifts', queryParameters: {'page': page, 'limit': limit});
      final data = res.data['data'];
      final List<dynamic> items = (data is Map ? (data['items'] ?? data['shifts']) : data) ?? [];
      return items.map((e) => ShiftModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw e.response?.data?['message'] ?? 'Gagal memuat riwayat shift';
    }
  }
}
