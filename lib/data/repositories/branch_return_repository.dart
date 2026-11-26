import 'package:dio/dio.dart';

import '../models/branch_return_model.dart';
import '../services/api_services.dart';
import 'kpi_repository.dart' show KpiApiError;

/// Retur Stok harian (revisi owner 26 Nov 2026). Stok outlet langsung
/// berkurang saat dikirim; barangnya lalu dipilah gudang di "Retur Harian".
class BranchReturnRepository {
  final ApiService api;
  BranchReturnRepository(this.api);

  /// `GET /branch-returns/items` — barang yang boleh diretur, dengan stoknya.
  Future<List<BranchReturnItem>> items() async {
    try {
      final res = await api.dio.get('/branch-returns/items');
      final data = res.data['data'];
      return [
        if (data is List)
          for (final e in data)
            if (e is Map) BranchReturnItem.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      throw _error(e, 'Gagal memuat barang retur');
    }
  }

  /// `POST /branch-returns`. [qty] per kunci `itemType-itemId`, desimal, satuan
  /// dasar barang. Retur yang melebihi stok sistem ditolak 422.
  Future<BranchReturnDoc> create({required List<BranchReturnItem> items, required Map<String, String> qty, String note = ''}) async {
    try {
      final res = await api.dio.post('/branch-returns', data: {
        if (note.trim().isNotEmpty) 'note': note.trim(),
        'items': [
          for (final it in items)
            if ((qty[it.key] ?? '').trim().isNotEmpty)
              {'item_type': it.itemType, 'item_id': it.itemId, 'qty': qty[it.key]!.trim()},
        ],
      });
      return BranchReturnDoc.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
    } on DioException catch (e) {
      throw _error(e, 'Gagal menyimpan retur');
    }
  }

  /// `GET /branch-returns` — riwayat retur harian cabang ini, terbaru dulu.
  Future<List<BranchReturnDoc>> history() async {
    try {
      final res = await api.dio.get('/branch-returns');
      final data = res.data['data'];
      return [
        if (data is List)
          for (final e in data)
            if (e is Map) BranchReturnDoc.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      throw _error(e, 'Gagal memuat riwayat retur');
    }
  }

  KpiApiError _error(DioException e, String fallback) {
    final data = e.response?.data;
    final status = e.response?.statusCode;
    final code = data is Map ? data['code']?.toString() : null;
    final msg = data is Map ? (data['message'] ?? data['error'])?.toString() : null;
    if (msg != null && msg.isNotEmpty) return KpiApiError(msg, code: code, status: status);
    if (e.response == null) return KpiApiError('$fallback: periksa koneksi internet');
    return KpiApiError('$fallback ($status)', code: code, status: status);
  }
}
