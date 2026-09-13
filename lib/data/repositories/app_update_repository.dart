import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:pos_mobile/data/models/app_release_model.dart';

/// Membaca rilis aktif dari `GET /app-version`.
///
/// Sengaja memakai Dio sendiri, bukan `ApiService`. Endpoint ini publik dan
/// dipanggil juga sebelum login; lewat klien utama ia akan melewati
/// interceptor refresh token, dan respons 401 yang tidak ada hubungannya
/// dengan versi bisa menyeret pengecekan ini ke alur logout paksa.
class AppUpdateRepository {
  final Dio _dio;

  /// Selektor aplikasi di BE. Aplikasi kasir memakai nilai bawaan, jadi
  /// parameternya tidak dikirim sama sekali; aplikasi gudang mengisinya
  /// `'gudang'`. Lihat `appFromRequest` di be-pos.
  final String? appKey;

  AppUpdateRepository({Dio? client, this.appKey})
      : _dio = client ??
            Dio(
              BaseOptions(
                baseUrl: dotenv.env['API_BASE_URL'] ?? '',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  /// Mengembalikan `null` bila server belum punya rilis aktif — itu keadaan
  /// normal (BE menjawab 404), bukan kegagalan. Kegagalan lain dilempar
  /// sebagai [String] pesan siap tampil, mengikuti repository lain di proyek
  /// ini.
  Future<AppReleaseInfo?> fetchActive() async {
    try {
      final res = await _dio.get(
        '/app-version',
        queryParameters: appKey == null ? null : {'app': appKey},
      );
      final data = res.data is Map ? res.data['data'] : null;
      if (data is! Map) throw 'Respons versi aplikasi tidak dikenali';
      return AppReleaseInfo.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _message(e, 'Gagal memeriksa versi terbaru');
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    final raw = (data is Map) ? (data['message'] ?? data['error']) : null;
    final msg = raw?.toString().trim();
    return (msg == null || msg.isEmpty) ? fallback : msg;
  }
}
