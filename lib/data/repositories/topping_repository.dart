import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/topping_model.dart';
import '../models/topping_stock_model.dart';
import '../models/topping_stock_movement_model.dart';

class ToppingRepository {
  final ApiService api;
  ToppingRepository(this.api);

  /// Ambil daftar topping. Default hanya yang aktif (untuk dipakai di POS).
  Future<List<Topping>> getToppings({bool activeOnly = true}) async {
    final res = await api.dio.get('/toppings');

    debugPrint('[ToppingRepo] status=${res.statusCode} body=${res.data}');

    final data = res.data['data'];
    if (data == null || data is! List) return [];

    final list = data.map((e) => Topping.fromJson(e)).toList();
    return activeOnly ? list.where((t) => t.isActive).toList() : list;
  }

  /// Daftar saldo stok topping.
  Future<List<ToppingStock>> getToppingStock() async {
    final res = await api.dio.get('/topping-stock');
    debugPrint('[ToppingRepo] stock status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => ToppingStock.fromJson(e)).toList();
  }

  /// Riwayat mutasi stok topping. Param opsional: topping_id.
  Future<List<ToppingStockMovement>> getToppingStockMovements({int? toppingId}) async {
    final res = await api.dio.get('/topping-stock/movements', queryParameters: {
      if (toppingId != null) 'topping_id': toppingId,
    });
    debugPrint('[ToppingRepo] movements status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => ToppingStockMovement.fromJson(e)).toList();
  }

  /// Set stok topping ke nilai absolut (qty bisa desimal). POST /topping-stock/adjust
  Future<void> adjustToppingStock({required int toppingId, required num newQty}) async {
    try {
      await api.dio.post('/topping-stock/adjust', data: {
        'topping_id': toppingId,
        'new_qty': newQty.toString(), // BE expects string ("500" / "82.5")
        'reference_type': 'manual',
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final m = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw m?.toString() ?? 'Gagal menyesuaikan stok topping (${e.response?.statusCode ?? e.message})';
    }
  }
}
