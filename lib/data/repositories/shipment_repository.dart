import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/shipment_model.dart';
import '../services/api_services.dart';

/// Kiriman gudang → outlet (BE Stasiun 4).
///
/// Sisi outlet saja: melihat apa yang datang, lalu menerima atau menolaknya.
/// Menerbitkan surat jalan dan menariknya ada di web admin — app ini sengaja
/// tidak memanggil keduanya meski endpoint-nya ada.
class ShipmentRepository {
  final ApiService api;
  ShipmentRepository(this.api);

  /// Daftar kiriman untuk cabang aktif. Cakupannya diurus BE dari token, jadi
  /// app tidak perlu mengirim branch_id.
  Future<List<Shipment>> getShipments({String? status}) async {
    try {
      final res = await api.dio.get('/shipments', queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        'limit': 100,
      });
      debugPrint('[ShipmentRepo] list status=${res.statusCode}');
      final data = res.data['data'];
      final items = (data is Map) ? data['items'] : null;
      if (items == null || items is! List) return [];
      return items
          .map((e) => Shipment.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memuat kiriman');
    }
  }

  Future<Shipment> getShipment(int id) async {
    try {
      final res = await api.dio.get('/shipments/$id');
      return Shipment.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw _msg(e, 'Gagal memuat detail kiriman');
    }
  }

  /// Menerima seluruh kiriman. Tidak ada isian jumlah — outlet menerima
  /// seluruhnya atau menolak seluruhnya.
  ///
  /// Stok outlet naik di sini, dan permintaan aslinya jadi selesai.
  Future<void> receive(int id) async {
    try {
      await api.dio.post('/shipments/$id/receive');
    } on DioException catch (e) {
      throw _msg(e, 'Gagal menerima kiriman');
    }
  }

  /// Menolak seluruh kiriman. Barang balik ke gudang dan permintaannya hidup
  /// lagi, jadi gudang bisa mengirim ulang tanpa outlet mengajukan dari nol.
  Future<void> reject(int id, String reason) async {
    try {
      await api.dio.post('/shipments/$id/reject', data: {'reason': reason});
    } on DioException catch (e) {
      throw _msg(e, 'Gagal menolak kiriman');
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

  /// Pesan dari BE sudah berbahasa Indonesia dan layak ditampilkan apa adanya;
  /// yang diterjemahkan di sini hanya yang butuh saran tindakan.
  String? _friendly(String? raw, int? statusCode) {
    final lower = raw?.toLowerCase().trim();

    if (statusCode == 404) {
      return 'Kiriman tidak ditemukan di cabang yang sedang aktif. '
          'Pindah cabang dulu kalau ini milik cabang lain.';
    }
    if (statusCode == 409) {
      return 'Kiriman ini sudah diputuskan sebelumnya — mungkin rekan kerja '
          'sudah menerimanya. Muat ulang untuk melihat keadaan terbaru.';
    }
    if (lower == 'unauthorized') {
      return 'Sesi sudah berakhir. Masuk ulang lalu coba lagi.';
    }
    // 400 dari endpoint kiriman selalu berupa 'invalid request' — satu-satunya
    // pesan BE di alur ini yang masih berbahasa Inggris dan tidak menyebut
    // sebabnya. Menampilkannya apa adanya membuat kasir mengira dirinya salah
    // pencet, padahal ini kesalahan di sisi server yang tidak bisa dia benahi.
    if (statusCode == 400) {
      return 'Kiriman ini ditolak server dan bukan karena kesalahanmu. '
          'Muat ulang dulu; kalau masih sama, laporkan ke admin gudang.';
    }
    return null;
  }
}
