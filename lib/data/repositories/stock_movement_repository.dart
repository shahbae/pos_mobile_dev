import '../services/api_services.dart';
import '../models/page_result.dart';
import '../models/stock_movement_model.dart';

class StockMovementRepository {
  final ApiService api;
  StockMovementRepository(this.api);

  /// Satu halaman riwayat mutasi bahan (terbaru dulu). Param opsional: material_id.
  Future<PageResult<StockMovementModel>> getStockMovementPage({
    int? materialId,
    required int page,
    required int limit,
  }) async {
    final res = await api.dio.get(
      '/stock-movements',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (materialId != null) 'material_id': materialId,
      },
    );
    return PageResult.parse(
      res.data['data'],
      StockMovementModel.fromJson,
      page: page,
      limit: limit,
    );
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
