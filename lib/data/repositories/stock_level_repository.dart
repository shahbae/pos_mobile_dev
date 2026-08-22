import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/stock_level_model.dart';

class StockLevelRepository {
  final ApiService api;
  StockLevelRepository(this.api);

  /// Daftar stok level per material (BE sudah material-level).
  Future<List<StockLevelModel>> getMaterialStockLevels() async {
    try {
      final res = await api.dio.get('/stock-levels');
      debugPrint('[StockLevelRepo] levels status=${res.statusCode} body=${res.data}');
      final data = res.data['data'];
      if (data == null || data is! List) return [];
      return data.map((e) => StockLevelModel.fromJson(e)).toList();
    } on DioException catch (e) {
      debugPrint('[StockLevelRepo] levels FAILED type=${e.type} '
          'status=${e.response?.statusCode} body=${e.response?.data} err=${e.error}');
      throw _mapError(e, 'stok material');
    }
  }

  /// DioException → pesan siap tampil (+ kode status supaya mudah dilacak).
  static String _mapError(DioException e, String what) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Koneksi timeout saat memuat $what. Periksa jaringan lalu coba lagi.';
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return 'Tidak bisa terhubung ke server. Periksa jaringan lalu coba lagi.';
      default:
        break;
    }
    final status = e.response?.statusCode;
    final d = e.response?.data;
    final msg = (d is Map ? (d['message'] ?? d['error']) : null)?.toString();
    if (status == 401) return 'Sesi berakhir. Silakan login ulang.';
    if (status == 403) {
      return msg != null && msg.toLowerCase().contains('branch')
          ? 'Akun belum di-assign ke cabang.'
          : 'Akun ini tidak punya akses ke $what.';
    }
    if (status != null && status >= 500) {
      return 'Server bermasalah saat memuat $what (500). Coba lagi sebentar lagi.';
    }
    return msg ?? 'Gagal memuat $what (${status ?? e.message}).';
  }

  /// Set stok material ke nilai absolut. POST /stock/adjust
  ///
  /// Stok material kini DESIMAL — BE minta new_qty sebagai STRING ("2400" / "12.5").
  Future<void> adjustStock({required int materialId, required num newQty}) async {
    try {
      await api.dio.post('/stock/adjust', data: {
        'material_id': materialId,
        'new_qty': newQty.toString(),
        'reference_type': 'manual',
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final m = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw m?.toString() ?? 'Gagal menyesuaikan stok (${e.response?.statusCode ?? e.message})';
    }
  }

  Future<StockLevelModel?> getStockLevel(int productId) async {
    try {
      final res = await api.dio.get(
        '/stock-levels',
        queryParameters: {'product_id': productId},
      );

      debugPrint('[StockLevelRepo] status=${res.statusCode} body=${res.data}');

      final data = res.data['data'];
      if (data == null) return null;

      // Ensure that we parse from array if returned as array, or map directly
      if (data is List && data.isNotEmpty) {
         return StockLevelModel.fromJson(data.first);
      } else if (data is Map<String, dynamic>) {
         return StockLevelModel.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[StockLevelRepo] Error fetching stock level: $e');
      return null;
    }
  }
}
