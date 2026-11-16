import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/branch_waste_model.dart';
import '../services/api_services.dart';
import 'kpi_repository.dart' show KpiApiError;

/// Waste outlet (revisi 15 Nov, poin 1). Mencatat langsung memotong stok
/// cabang dan tidak boleh minus; salah catat dikoreksi lewat opname, jadi tak
/// ada ubah atau hapus. Foto dikirim sebagai byte yang sudah dibaca ke memori,
/// bukan path (pelajaran "PathNotFoundException", 10 Okt).
class BranchWasteRepository {
  final ApiService api;
  BranchWasteRepository(this.api);

  /// `GET /branch-wastes/items` — barang cabang ini yang stoknya lebih dari nol.
  Future<List<BranchWasteItem>> items() async {
    try {
      final res = await api.dio.get('/branch-wastes/items');
      final data = res.data['data'];
      return [
        if (data is List)
          for (final e in data)
            if (e is Map) BranchWasteItem.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      throw _error(e, 'Gagal memuat daftar barang');
    }
  }

  /// `POST /branch-wastes` (multipart). 422 `branch_stock_not_enough` bila stok
  /// kurang: pesannya ditampilkan apa adanya.
  Future<BranchWasteRecord> create({
    required String itemType,
    required int itemId,
    required String qty,
    required String cause,
    String note = '',
    required Uint8List photo,
  }) async {
    try {
      final res = await api.dio.post(
        '/branch-wastes',
        data: FormData.fromMap({
          'item_type': itemType,
          'item_id': '$itemId',
          'qty': qty,
          'cause': cause,
          if (note.isNotEmpty) 'note': note,
          'photo': MultipartFile.fromBytes(photo, filename: 'waste-$itemType-$itemId.jpg'),
        }),
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return BranchWasteRecord.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
    } on DioException catch (e) {
      throw _error(e, 'Gagal mencatat waste');
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
