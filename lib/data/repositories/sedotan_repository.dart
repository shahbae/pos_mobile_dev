import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/sedotan_model.dart';
import '../models/sedotan_stock_model.dart';
import '../models/sedotan_stock_movement_model.dart';

class SedotanRepository {
  final ApiService api;
  SedotanRepository(this.api);

  /// Ambil daftar sedotan. Default hanya yang aktif (untuk dipakai di POS).
  Future<List<Sedotan>> getSedotans({bool activeOnly = true}) async {
    final res = await api.dio.get('/sedotans');
    debugPrint('[SedotanRepo] status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    final list = data.map((e) => Sedotan.fromJson(e)).toList();
    return activeOnly ? list.where((s) => s.isActive).toList() : list;
  }

  /// Daftar saldo stok sedotan per cabang.
  Future<List<SedotanStock>> getSedotanStock() async {
    final res = await api.dio.get('/sedotan-stock');
    debugPrint('[SedotanRepo] stock status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => SedotanStock.fromJson(e)).toList();
  }

  /// Riwayat mutasi stok sedotan. Param opsional: sedotan_id.
  Future<List<SedotanStockMovement>> getSedotanStockMovements({int? sedotanId}) async {
    final res = await api.dio.get('/sedotan-stock/movements', queryParameters: {
      if (sedotanId != null) 'sedotan_id': sedotanId,
    });
    debugPrint('[SedotanRepo] movements status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => SedotanStockMovement.fromJson(e)).toList();
  }

  /// Set stok sedotan ke nilai absolut (qty bisa desimal). POST /sedotan-stock/adjust
  Future<void> adjustSedotanStock({required int sedotanId, required num newQty}) async {
    try {
      await api.dio.post('/sedotan-stock/adjust', data: {
        'sedotan_id': sedotanId,
        'new_qty': newQty.toString(), // BE expects string ("500" / "82.5")
        'reference_type': 'manual',
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final m = (data is Map) ? (data['message'] ?? data['error']) : null;
      throw m?.toString() ??
          'Gagal menyesuaikan stok sedotan (${e.response?.statusCode ?? e.message})';
    }
  }
}
