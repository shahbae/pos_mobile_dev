import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:pos_mobile/data/services/secure_storage.dart';

class ApiService {
  late final Dio dio;
  final Dio _authClient = Dio(); // khusus refresh — tanpa interceptor

  /// Single-flight: satu proses refresh dipakai bersama semua request yang
  /// kena 401 bersamaan. Tanpa ini, refresh token yang dirotasi BE akan
  /// dipakai berkali-kali → request kedua gagal → user logout paksa.
  Future<bool>? _refreshing;

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL']!,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
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

          final refreshed = await _refreshSingleFlight();

          if (!refreshed) {
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

          try {
            final clone = await dio.request(
              req.path,
              data: req.data,
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
  Future<bool> _refreshSingleFlight() {
    return _refreshing ??= _refreshToken().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _refreshToken() async {
    final refresh = await SecureStorage.getRefreshToken();
    if (refresh == null) return false;

    try {
      final res = await _authClient.post(
        '${dotenv.env['API_BASE_URL']!}/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (res.data['success'] != true) return false;

      final data = res.data['data'];
      final token = data?['access_token'];

      if (token == null) return false;

      await SecureStorage.saveTokens(
        accessToken: token,
        refreshToken: data?['refresh_token'],
      );

      return true;
    } catch (_) {
      return false;
    }
  }
}
