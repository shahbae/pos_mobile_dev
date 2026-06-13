import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/stock_movement_model.dart';

class StockMovementRepository {
  final ApiService api;
  StockMovementRepository(this.api);

  Future<List<StockMovementModel>> getStockMovements({
    int? materialId,
  }) async {
    final res = await api.dio.get(
      '/stock-movements',
      queryParameters: {
        if (materialId != null) 'material_id': materialId,
      },
    );

    debugPrint('[StockMovementRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null) return [];

    List listData = [];
    if (data is List) {
      listData = data;
    } else if (data is Map && data['data'] is List) {
      listData = data['data'];
    }

    return listData.map((e) => StockMovementModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> createStockMovement(Map<String, dynamic> data) async {
    final res = await api.dio.post('/stock-movements', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> adjustStock(Map<String, dynamic> data) async {
    final res = await api.dio.post('/stock/adjust', data: data);
    return res.data;
  }
}
