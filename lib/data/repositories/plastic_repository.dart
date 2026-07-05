import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/plastic_model.dart';
import '../models/plastic_stock_model.dart';
import '../models/plastic_stock_movement_model.dart';

class PlasticRepository {
  final ApiService api;
  PlasticRepository(this.api);

  /// Ambil daftar plastik. Default hanya yang aktif (untuk dipakai di POS).
  Future<List<Plastic>> getPlastics({bool activeOnly = true}) async {
    final res = await api.dio.get('/plastics');
    debugPrint('[PlasticRepo] status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    final list = data.map((e) => Plastic.fromJson(e)).toList();
    return activeOnly ? list.where((p) => p.isActive).toList() : list;
  }

  /// Daftar saldo stok plastik per cabang.
  Future<List<PlasticStock>> getPlasticStock() async {
    final res = await api.dio.get('/plastic-stock');
    debugPrint('[PlasticRepo] stock status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => PlasticStock.fromJson(e)).toList();
  }

  /// Riwayat mutasi stok plastik. Param opsional: plastic_id.
  Future<List<PlasticStockMovement>> getPlasticStockMovements({int? plasticId}) async {
    final res = await api.dio.get('/plastic-stock/movements', queryParameters: {
      if (plasticId != null) 'plastic_id': plasticId,
    });
    debugPrint('[PlasticRepo] movements status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => PlasticStockMovement.fromJson(e)).toList();
  }

  /// Set stok plastik ke nilai absolut (qty bisa desimal). POST /plastic-stock/adjust
  Future<void> adjustPlasticStock({required int plasticId, required num newQty}) async {
    try {
      await api.dio.post('/plastic-stock/adjust', data: {
        'plastic_id': plasticId,
        'new_qty': newQty.toString(), // BE expects string ("500" / "82.5")
        'reference_type': 'manual',
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final m = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw m?.toString() ??
          'Gagal menyesuaikan stok plastik (${e.response?.statusCode ?? e.message})';
    }
  }
}
