import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'secure_storage.dart';

class ApiService {
  late final Dio dio;
  final Dio _authClient = Dio(); // khusus refresh — tanpa interceptor

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL']!,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (status) => status != null && status < 500,
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
          // hanya tangani 401
          if (e.response?.statusCode == 401) {
            final refreshed = await _refreshToken();

            if (refreshed) {
              final newToken = await SecureStorage.getAccessToken();

              final opts = Options(
                method: e.requestOptions.method,
                headers: {
                  ...e.requestOptions.headers,
                  'Authorization': 'Bearer $newToken',
                },
              );

              try {
                final clone = await dio.request(
                  e.requestOptions.path,
                  data: e.requestOptions.data,
                  queryParameters: e.requestOptions.queryParameters,
                  options: opts,
                );

                return handler.resolve(clone);
              } catch (_) {
                await SecureStorage.clear();
              }
            } else {
              await SecureStorage.clear();
            }
          }

          return handler.next(e);
        },
      ),
    );
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
