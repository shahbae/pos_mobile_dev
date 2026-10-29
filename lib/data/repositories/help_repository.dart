import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/help_ticket_model.dart';
import '../services/api_services.dart';

/// Tiket bantuan leader (Tahap 4, F12). SPV dan finance menanggapinya di web
/// admin; di app leader membuat, mengonfirmasi, dan membuka kembali.
class HelpRepository {
  final ApiService api;
  HelpRepository(this.api);

  /// `GET /help-categories?active=true`.
  Future<List<HelpCategory>> categories() async {
    try {
      final res = await api.dio.get('/help-categories', queryParameters: {'active': true});
      final data = res.data['data'];
      if (data is! List) return const [];
      return [
        for (final e in data)
          if (e is Map) HelpCategory.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      throw _message(e, 'Gagal memuat kategori');
    }
  }

  /// `GET /help-tickets?scope=mine` — tiket buatan leader ini, terbaru di atas.
  Future<List<HelpTicket>> mine({int limit = 50}) async {
    try {
      final res = await api.dio.get('/help-tickets', queryParameters: {'scope': 'mine', 'limit': limit});
      final items = (res.data['data'] as Map?)?['items'];
      if (items is! List) return const [];
      return [
        for (final e in items)
          if (e is Map) HelpTicket.fromJson(Map<String, dynamic>.from(e)),
      ];
    } on DioException catch (e) {
      throw _message(e, 'Gagal memuat tiket');
    }
  }

  /// `GET /help-tickets/:id` — dengan riwayat status. Juga tujuan ketukan
  /// notifikasi `app:/help-tickets/<id>`.
  Future<HelpTicket> one(int id) => _one(() => api.dio.get('/help-tickets/$id'), 'Gagal memuat tiket');

  /// `POST /help-tickets` (multipart). Outlet diambil server dari akun leader.
  Future<HelpTicket> create({
    required String target,
    required int categoryId,
    required String description,
    Uint8List? photo,
    String? photoName,
  }) =>
      _one(
        () => api.dio.post(
          '/help-tickets',
          data: FormData.fromMap({
            'target': target,
            'category_id': '$categoryId',
            'description': description,
            if (photo != null) 'photo': MultipartFile.fromBytes(photo, filename: photoName ?? 'tiket.jpg'),
          }),
          options: Options(contentType: 'multipart/form-data'),
        ),
        'Gagal membuat tiket',
      );

  /// `POST /help-tickets/:id/reopen` — kembali ke disetujui dengan tenggat lama.
  Future<HelpTicket> reopen(int id, {String? note}) => _one(
    () => api.dio.post('/help-tickets/$id/reopen', data: {if (note != null && note.isNotEmpty) 'note': note}),
    'Gagal membuka kembali tiket',
  );

  /// `POST /help-tickets/:id/confirm`.
  Future<HelpTicket> confirm(int id) =>
      _one(() => api.dio.post('/help-tickets/$id/confirm'), 'Gagal mengonfirmasi tiket');

  Future<HelpTicket> _one(Future<Response<dynamic>> Function() call, String fallback) async {
    try {
      final res = await call();
      return HelpTicket.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
    } on DioException catch (e) {
      throw _message(e, fallback);
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    final msg = data is Map ? (data['message'] ?? data['error'])?.toString() : null;
    if (msg != null && msg.isNotEmpty) return msg;
    if (e.response == null) return '$fallback: periksa koneksi internet';
    return '$fallback (${e.response?.statusCode})';
  }
}
