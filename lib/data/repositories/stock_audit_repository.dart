import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/stock_audit_model.dart';

class StockAuditRepository {
  final ApiService api;
  StockAuditRepository(this.api);

  /// List audit (tanpa items). Role non-owner wajib punya konteks cabang
  /// (BE 2026-08-03 §4) — kalau belum pilih cabang, BE balas 400.
  Future<List<StockAudit>> getAudits() async {
    try {
      final res = await api.dio.get('/stock-audits');
      debugPrint('[StockAuditRepo] list status=${res.statusCode} body=${res.data}');
      final data = res.data['data'];
      if (data == null || data is! List) return [];
      return data.map((e) => StockAudit.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memuat audit stok');
    }
  }

  /// Detail audit (dengan items). Audit milik cabang lain → 404 (BE sengaja
  /// tidak membocorkan keberadaannya lewat 403).
  Future<StockAudit> getAudit(int id) async {
    try {
      final res = await api.dio.get('/stock-audits/$id');
      return StockAudit.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memuat detail audit');
    }
  }

  /// Buat audit baru.
  /// items: [{material_id|topping_id, physical_qty, returned_qty?}]
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

  /// Perbarui draft audit (notes + items). Snapshot dihitung ulang oleh BE.
  /// Draft-only; audit approved → 409. branch_id tidak dikirim (tetap).
  Future<StockAudit> updateAudit({
    required int id,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final res = await api.dio.put('/stock-audits/$id', data: {
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      });
      return StockAudit.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memperbarui audit stok');
    }
  }

  /// Hapus draft audit beserta itemnya. Draft-only; audit approved → 409.
  Future<void> deleteAudit(int id) async {
    try {
      await api.dio.delete('/stock-audits/$id');
    } on DioException catch (e) {
      throw _msg(e, 'Gagal menghapus audit stok');
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
    final raw = m?.toString();
    final friendly = _friendly(raw);
    if (friendly != null) return friendly;
    // 404 pada audit umumnya berarti audit tsb milik cabang lain (BE 2026-08-03
    // §4 memakai 404, bukan 403, supaya keberadaannya tidak bocor).
    if (e.response?.statusCode == 404) {
      return 'Audit tidak ditemukan di cabang yang sedang aktif. '
          'Pindah cabang dulu kalau audit ini milik cabang lain.';
    }
    return raw ?? '$fallback (${e.response?.statusCode ?? e.message})';
  }

  /// Terjemahkan pesan error BE yang dikenal ke bahasa Indonesia yang ramah.
  String? _friendly(String? code) {
    final lower = code?.toLowerCase().trim();
    if (lower != null && lower.startsWith('branch context required')) {
      return 'Pilih cabang dulu sebelum membuka audit stok.';
    }
    if (lower == 'not found') {
      return 'Audit tidak ditemukan di cabang yang sedang aktif. '
          'Pindah cabang dulu kalau audit ini milik cabang lain.';
    }
    switch (lower) {
      case 'insufficient stock to apply audit adjustment':
        return 'Stok saat ini tidak cukup untuk menerapkan penyesuaian audit. '
            'Hitung ulang stok fisik lalu coba lagi.';
      case 'audit already approved':
        return 'Audit sudah disetujui, tidak bisa diubah atau dihapus.';
      case 'duplicate item in audit':
        return 'Ada item yang tercatat lebih dari sekali dalam audit.';
      case 'invalid input':
        return 'Input tidak valid. Pastikan jumlah bahan berupa bilangan bulat.';
      default:
        return null;
    }
  }
}
