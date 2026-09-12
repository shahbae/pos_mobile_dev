import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/stock_request_model.dart';
import '../services/api_services.dart';

/// Permintaan stok outlet ke gudang (BE Stasiun 3).
///
/// Sisi outlet saja: mengajukan, mengubah selagi belum diputuskan, membatalkan,
/// memantau. Acc dan tolak ada di web admin — app ini sengaja tidak memanggil
/// keduanya meski endpoint-nya ada.
class StockRequestRepository {
  final ApiService api;
  StockRequestRepository(this.api);

  /// Katalog barang yang boleh diminta beserta pilihan kemasannya.
  ///
  /// Bisa **kosong** kalau belum ada barang setengah jadi yang ditandai atau
  /// belum ada yang punya kemasan. Itu keadaan yang wajar di awal, jadi UI harus
  /// menjelaskannya, bukan memutar spinner selamanya.
  Future<List<RequestableItem>> getRequestableItems() async {
    try {
      final res = await api.dio.get('/stock-requests/requestable-items');
      debugPrint('[StockRequestRepo] catalogue status=${res.statusCode}');
      final data = res.data['data'];
      if (data == null || data is! List) return [];
      return data
          .map((e) => RequestableItem.fromJson(e as Map<String, dynamic>))
          // Barang tanpa kemasan tidak bisa dipesan jumlahnya; BE sudah
          // menyaringnya, ini jaring pengaman kalau kontraknya berubah.
          .where((e) => e.templates.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memuat daftar barang');
    }
  }

  /// Daftar permintaan. Leader otomatis hanya melihat cabangnya sendiri —
  /// cakupannya diurus BE dari token, app tidak perlu mengirim branch_id.
  Future<List<StockRequest>> getRequests({String? status}) async {
    try {
      final res = await api.dio.get('/stock-requests', queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        'limit': 100,
      });
      final data = res.data['data'];
      final items = (data is Map) ? data['items'] : null;
      if (items == null || items is! List) return [];
      return items
          .map((e) => StockRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memuat permintaan stok');
    }
  }

  /// Detail dengan `lines` yang sudah berisi nama barang & stok gudang.
  /// Permintaan cabang lain dibalas 404, bukan 403 — BE sengaja tidak
  /// membocorkan keberadaannya.
  Future<StockRequest> getRequest(int id) async {
    try {
      final res = await api.dio.get('/stock-requests/$id');
      return StockRequest.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memuat detail permintaan');
    }
  }

  /// items: [{item_type, item_id, template_id, pack_qty}] — `pack_qty` sebagai
  /// TEKS, mengikuti seluruh endpoint stok, supaya pecahan tidak dibulatkan.
  Future<StockRequest> createRequest({
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final res = await api.dio.post('/stock-requests', data: {
        if (note != null && note.isNotEmpty) 'note': note,
        'items': items,
      });
      return StockRequest.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw _msg(e, 'Gagal membuat permintaan stok');
    }
  }

  /// Mengganti SELURUH baris, bukan menambah. Hanya selagi berstatus
  /// `submitted`, dan hanya oleh pembuatnya.
  Future<StockRequest> updateRequest({
    required int id,
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final res = await api.dio.put('/stock-requests/$id', data: {
        if (note != null && note.isNotEmpty) 'note': note,
        'items': items,
      });
      return StockRequest.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memperbarui permintaan stok');
    }
  }

  Future<void> cancelRequest(int id) async {
    try {
      await api.dio.post('/stock-requests/$id/cancel');
    } on DioException catch (e) {
      throw _msg(e, 'Gagal membatalkan permintaan');
    }
  }

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    final m = (data is Map) ? (data['message'] ?? data['error']) : null;
    final raw = m?.toString();
    final friendly = _friendly(raw, e.response?.statusCode);
    if (friendly != null) return friendly;
    return raw ?? '$fallback (${e.response?.statusCode ?? e.message})';
  }

  /// Pesan 422 dari BE sudah berbahasa Indonesia dan layak ditampilkan apa
  /// adanya; yang diterjemahkan di sini hanya yang masih berupa kode teknis
  /// atau yang butuh saran tindakan.
  String? _friendly(String? raw, int? statusCode) {
    final lower = raw?.toLowerCase().trim();

    if (statusCode == 404) {
      return 'Permintaan tidak ditemukan di cabang yang sedang aktif. '
          'Pindah cabang dulu kalau ini milik cabang lain.';
    }
    if (statusCode == 403) {
      return 'Permintaan ini dibuat orang lain, jadi hanya dia yang boleh '
          'mengubahnya. Buat permintaan baru kalau ada yang kurang.';
    }
    if (statusCode == 409) {
      return 'Permintaan ini sudah diputuskan gudang, jadi tidak bisa diubah '
          'lagi. Muat ulang untuk melihat keputusannya.';
    }
    if (lower != null && lower.startsWith('branch_id')) {
      return 'Pilih cabang dulu sebelum mengajukan permintaan.';
    }
    switch (lower) {
      case 'invalid request':
        return 'Isian belum lengkap atau jumlahnya tidak masuk akal. '
            'Pastikan tiap barang punya jumlah lebih dari nol.';
      case 'unauthorized':
        return 'Sesi sudah berakhir. Masuk ulang lalu coba lagi.';
      default:
        return null;
    }
  }
}
