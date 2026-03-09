import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/stock_level_model.dart';

class StockLevelRepository {
  final ApiService api;
  StockLevelRepository(this.api);

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
