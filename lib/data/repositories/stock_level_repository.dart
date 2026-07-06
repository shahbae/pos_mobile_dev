import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/stock_level_model.dart';

class StockLevelRepository {
  final ApiService api;
  StockLevelRepository(this.api);

  /// Daftar stok level per material (BE sudah material-level).
  Future<List<StockLevelModel>> getMaterialStockLevels() async {
    final res = await api.dio.get('/stock-levels');
    debugPrint('[StockLevelRepo] levels status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => StockLevelModel.fromJson(e)).toList();
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
