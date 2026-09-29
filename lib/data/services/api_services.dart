import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:pos_mobile/data/services/secure_storage.dart';

class ApiService {
  late final Dio dio;

  /// Khusus refresh — tanpa interceptor. Wajib punya timeout sendiri: semua
  /// request yang kena 401 menunggu refresh yang sama (single-flight), jadi
  /// satu refresh yang menggantung di jaringan jelek membuat SEMUA layar
  /// berputar tanpa akhir sampai aplikasi ditutup paksa.
  final Dio _authClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Single-flight: satu proses refresh dipakai bersama semua request yang
  /// kena 401 bersamaan. Tanpa ini, refresh token yang dirotasi BE akan
  /// dipakai berkali-kali → request kedua gagal → user logout paksa.
  Future<_RefreshResult>? _refreshing;

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL']!,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        // Total waktu kirim body. Tanpa ini unggahan foto (absensi,
        // pengeluaran, hasil produksi) di sinyal jelek bisa menggantung
        // selamanya. Foto sudah dikompres ke ≤1280 px, jadi 60 dtk longgar.
        sendTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          debugPrint('[API] ${options.method} ${options.path} token=${token != null ? 'YES' : 'NO'}');
          return handler.next(options);
        },

        onError: (e, handler) async {
          final req = e.requestOptions;

          // Hanya tangani 401. Lewati bila:
          // - request ini sudah pernah di-retry (hindari loop tak berujung), atau
          // - request ke endpoint auth (login/refresh/logout tak boleh di-refresh).
          final alreadyRetried = req.extra['__retried'] == true;
          if (e.response?.statusCode != 401 ||
              alreadyRetried ||
              _isAuthPath(req.path)) {
            return handler.next(e);
          }

          final result = await _refreshSingleFlight();

          if (result.networkError != null) {
            // Gagal karena jaringan, bukan karena token ditolak — token
            // disimpan supaya user cukup coba lagi, tidak dipaksa login ulang.
            // Error jaringan yang diteruskan (bukan 401 aslinya) supaya pesan
            // di layar "periksa koneksi", bukan "sesi berakhir".
            return handler.next(
              result.networkError!.copyWith(requestOptions: req),
            );
          }

          if (!result.ok) {
            await SecureStorage.clear();
            return handler.next(e);
          }

          final newToken = await SecureStorage.getAccessToken();
          final opts = Options(
            method: req.method,
            headers: {
              ...req.headers,
              'Authorization': 'Bearer $newToken',
            },
            extra: {...req.extra, '__retried': true},
          );

          // FormData hanya bisa dikirim SEKALI — stream file-nya sudah habis
          // dibaca saat percobaan pertama. Mengirim ulang objek yang sama
          // melempar error di sisi klien, jadi request-nya tidak pernah sampai
          // ke server. Ini yang membuat absensi dan pengeluaran (satu-satunya
          // yang memakai multipart) gagal tepat ketika token kebetulan
          // kedaluwarsa saat tombol ditekan. clone() membangun ulang body-nya
          // dari file di disk.
          final body = req.data is FormData
              ? (req.data as FormData).clone()
              : req.data;

          try {
            final clone = await dio.request(
              req.path,
              data: body,
              queryParameters: req.queryParameters,
              options: opts,
            );
            return handler.resolve(clone);
          } catch (err) {
            return handler.next(err is DioException ? err : e);
          }
        },
      ),
    );
  }

  bool _isAuthPath(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/refresh') ||
      path.contains('/auth/logout');

  /// Menjamin hanya ada SATU proses refresh berjalan. Request lain yang kena
  /// 401 di saat bersamaan ikut menunggu Future yang sama.
  Future<_RefreshResult> _refreshSingleFlight() {
    return _refreshing ??= _refreshToken().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<_RefreshResult> _refreshToken() async {
    final refresh = await SecureStorage.getRefreshToken();
    if (refresh == null) return _RefreshResult.rejected;

    try {
      final res = await _authClient.post(
        '${dotenv.env['API_BASE_URL']!}/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (res.data['success'] != true) return _RefreshResult.rejected;

      final data = res.data['data'];
      final token = data?['access_token'];

      if (token == null) return _RefreshResult.rejected;

      await SecureStorage.saveTokens(
        accessToken: token,
        refreshToken: data?['refresh_token'],
      );

      return _RefreshResult.success;
    } on DioException catch (err) {
      // Ada respons = server menjawab dan menolak (401 dsb.). Tanpa respons =
      // timeout / koneksi putus, refresh token-nya belum tentu tidak sah.
      if (err.response != null) return _RefreshResult.rejected;
      return _RefreshResult(ok: false, networkError: err);
    } catch (_) {
      return _RefreshResult.rejected;
    }
  }
}

class _RefreshResult {
  final bool ok;
  final DioException? networkError;

  const _RefreshResult({required this.ok, this.networkError});

  static const success = _RefreshResult(ok: true);
  static const rejected = _RefreshResult(ok: false);
}
