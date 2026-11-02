import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_services.dart';
import '../models/page_result.dart';
import '../models/stock_audit_model.dart';

/// Cabang masih punya draft opname yang belum disetujui (BE 2026-08-08 §2 —
/// 409). Dilempar sebagai tipe tersendiri supaya UI bisa menawarkan "buka draft
/// yang ada" alih-alih menampilkan error mentah.
class OpenDraftConflict implements Exception {
  final String message;
  OpenDraftConflict(this.message);
  @override
  String toString() => message;
}

/// Jenis berperiode ini sudah dibuat untuk periodenya (Tahap 5 — 409
/// audit_period_exists). Membawa id opname yang ada supaya layar bisa
/// langsung membukanya.
class AuditPeriodExists implements Exception {
  final int? auditId;
  final String message;
  AuditPeriodExists(this.auditId, this.message);
  @override
  String toString() => message;
}

class StockAuditRepository {
  final ApiService api;
  StockAuditRepository(this.api);

  /// Item yang boleh diaudit di cabang aktif (BE 2026-08-08 §1).
  /// Owner tanpa cabang aktif wajib mengirim [branchId].
  /// Daftar bisa kosong kalau owner belum mencentang apa pun.
  /// [type]: daily | weekly | monthly | general (bawaan BE: general).
  Future<List<AuditableItem>> getAuditableItems({int? branchId, String type = AuditTypes.general}) async {
    try {
      final res = await api.dio.get('/stock-audits/auditable-items',
          queryParameters: {if (branchId != null) 'branch_id': branchId, 'type': type});
      debugPrint('[StockAuditRepo] auditable status=${res.statusCode} body=${res.data}');
      final data = res.data['data'];
      if (data == null || data is! List) return [];
      return data
          .map((e) => AuditableItem.fromJson(e as Map<String, dynamic>))
          // Tipe yang belum dikenal app ini tidak punya id yang bisa dikirim
          // balik — lewati saja daripada mengirim item tanpa id.
          .where((e) => e.id != null)
          .toList();
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memuat item opname');
    }
  }

  // Catatan: PUT /stock-audits/auditable-items (mengatur item mana yang masuk
  // opname) sengaja TIDAK diimplementasikan di app ini — pengaturannya ada di
  // web admin, sama seperti master data lain (keputusan user 2026-08-08).

  /// Satu halaman audit (tanpa items), terbaru dulu. Role non-owner wajib
  /// punya konteks cabang (BE 2026-08-03 §4) — kalau belum pilih cabang, BE
  /// balas 400.
  Future<PageResult<StockAudit>> getAuditPage({
    required int page,
    required int limit,
  }) async {
    try {
      final res = await api.dio.get(
        '/stock-audits',
        queryParameters: {'page': page, 'limit': limit},
      );
      return PageResult.parse(
        res.data['data'],
        StockAudit.fromJson,
        page: page,
        limit: limit,
      );
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

  /// Keadaan Harian/Mingguan/Bulanan cabang aktif untuk periode berjalan
  /// (Tahap 5): kartu status di daftar dan syarat menutup Shift 2.
  Future<AuditPeriods> getPeriods() async {
    try {
      final res = await api.dio.get('/stock-audits/periods');
      return AuditPeriods.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memuat status opname');
    }
  }

  /// Buat audit baru. [auditType] daily | weekly | monthly | general.
  /// items: [{material_id|topping_id, physical_qty, returned_qty?}]
  Future<StockAudit> createAudit({
    String auditType = AuditTypes.general,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final res = await api.dio.post('/stock-audits', data: {
        'audit_type': auditType,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      });
      return StockAudit.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['code'] == 'audit_period_exists') {
        final id = (data['data'] is Map) ? (data['data']['audit_id'] as num?)?.toInt() : null;
        throw AuditPeriodExists(id,
            'Opname ${auditTypeLabel(auditType)} untuk periode ini sudah dibuat. Buka opname itu untuk melanjutkan.');
      }
      if (_isOpenDraftConflict(e)) {
        throw OpenDraftConflict(
            'Cabang ini masih punya draft opname yang belum disetujui. '
            'Lanjutkan draft tersebut, jangan buat yang baru.');
      }
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

  /// Isi alasan barang tidak wajar (Tahap 5). Angka sistem tidak dipotret
  /// ulang. items: [{material_id|topping_id|plastic_id|sedotan_id, reason}].
  Future<StockAudit> setReasons(int id, List<Map<String, dynamic>> items) async {
    try {
      final res = await api.dio.put('/stock-audits/$id/reasons', data: {'items': items});
      return StockAudit.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw _msg(e, 'Gagal menyimpan alasan');
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

  /// 409 "branch already has an open draft audit" — jaring pengaman BE saat
  /// tombol Simpan tertekan dua kali (dulu bikin stok terpotong dobel).
  bool _isOpenDraftConflict(DioException e) {
    if (e.response?.statusCode != 409) return false;
    final data = e.response?.data;
    final m = (data is Map) ? (data['message'] ?? data['error']) : null;
    return m?.toString().toLowerCase().contains('open draft') ?? false;
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
    if (lower != null && lower.startsWith('branch already has an open draft')) {
      return 'Cabang ini masih punya draft opname yang belum disetujui. '
          'Lanjutkan draft tersebut, jangan buat yang baru.';
    }
    switch (lower) {
      case 'item is not auditable':
        return 'Ada item yang sudah tidak masuk daftar opname. '
            'Tutup halaman ini lalu buka lagi supaya daftarnya diperbarui.';
      // Sejak BE 2026-08-08 §4 approve tidak lagi gagal karena stok kurang
      // (stok berhenti di 0 + shortfall_qty). Dipertahankan untuk BE lama.
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
