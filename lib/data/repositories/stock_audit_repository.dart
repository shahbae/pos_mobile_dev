import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/stock_audit_model.dart';

class StockAuditRepository {
  final ApiService api;
  StockAuditRepository(this.api);

  /// List audit (tanpa items).
  Future<List<StockAudit>> getAudits() async {
    final res = await api.dio.get('/stock-audits');
    debugPrint('[StockAuditRepo] list status=${res.statusCode} body=${res.data}');
    final data = res.data['data'];
    if (data == null || data is! List) return [];
    return data.map((e) => StockAudit.fromJson(e)).toList();
  }

  /// Detail audit (dengan items).
  Future<StockAudit> getAudit(int id) async {
    final res = await api.dio.get('/stock-audits/$id');
    return StockAudit.fromJson(res.data['data'] ?? res.data);
  }

  /// Buat audit baru.
  /// items: [{material_id, physical_qty}]
  Future<StockAudit> createAudit({
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final res = await api.dio.post('/stock-audits', data: {
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      });
      return StockAudit.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw _msg(e, 'Gagal membuat audit stok');
    }
  }

  /// Setujui audit. Mengembalikan audit yang sudah diperbarui (status approved).
  Future<StockAudit> approveAudit(int id) async {
    try {
      final res = await api.dio.post('/stock-audits/$id/approve');
      return StockAudit.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw _msg(e, 'Gagal menyetujui audit');
    }
  }

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    final m = (data is Map) ? (data['message'] ?? data['error']) : null;
    return m?.toString() ?? '$fallback (${e.response?.statusCode ?? e.message})';
  }
}
