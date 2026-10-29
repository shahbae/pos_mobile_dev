import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/reminder_model.dart';
import '../services/api_services.dart';

/// Reminder yang ditujukan ke akun ini (Tahap 4, F11). Mengirim reminder ada
/// di web admin; di app hanya membaca dan membalas.
class ReminderRepository {
  final ApiService api;
  ReminderRepository(this.api);

  /// `GET /me/reminders?status=pending` — pengecekan yang tenggatnya belum
  /// lewat dan catatan belum dibaca dari 24 jam terakhir. Ditarik tiap app
  /// dibuka: jaring pengaman bila notifikasinya tidak sampai.
  Future<MyReminderPage> pending() => _page({'status': 'pending'});

  /// `GET /me/reminders?page=&limit=` — riwayat, terbaru di atas.
  Future<MyReminderPage> history({int page = 1, int limit = 30}) => _page({'page': page, 'limit': limit});

  Future<MyReminderPage> _page(Map<String, dynamic> query) async {
    try {
      final res = await api.dio.get('/me/reminders', queryParameters: query);
      return MyReminderPage.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
    } on DioException catch (e) {
      throw _message(e, 'Gagal memuat reminder');
    }
  }

  /// `GET /me/reminders/:id` — dibuka dari ketukan notifikasi.
  Future<MyReminder> one(int id) => _one(() => api.dio.get('/me/reminders/$id'), 'Gagal memuat reminder');

  /// `POST /me/reminders/:id/open` — layar reminder tampil. Mencatat waktu
  /// baca; aman diulang.
  Future<MyReminder> open(int id) => _one(() => api.dio.post('/me/reminders/$id/open'), 'Gagal membuka reminder');

  /// `POST /me/reminders/:id/read` — tombol "Sudah dibaca" (catatan saja).
  Future<MyReminder> markRead(int id) =>
      _one(() => api.dio.post('/me/reminders/$id/read'), 'Gagal menandai sudah dibaca');

  /// `POST /me/reminders/:id/photos` — satu bagian, langsung begitu difoto.
  /// Isi foto sudah dipegang di memori, bukan path: folder cache tempat
  /// kamera menaruhnya boleh dikosongkan Android kapan saja (pelajaran
  /// "PathNotFoundException" app gudang, 10 Okt 2026).
  Future<MyReminder> uploadPhoto(int id, {required int partId, required Uint8List bytes, required String filename}) =>
      _one(
        () => api.dio.post(
          '/me/reminders/$id/photos',
          data: FormData.fromMap({
            'part_id': '$partId',
            'photo': MultipartFile.fromBytes(bytes, filename: filename),
          }),
          options: Options(contentType: 'multipart/form-data'),
        ),
        'Gagal mengirim foto',
      );

  Future<MyReminder> _one(Future<Response<dynamic>> Function() call, String fallback) async {
    try {
      final res = await call();
      return MyReminder.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
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
