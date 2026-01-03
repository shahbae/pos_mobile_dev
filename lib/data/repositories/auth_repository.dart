import 'package:dio/dio.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import '../services/secure_storage.dart';

class AuthRepository {
  final ApiService api;

  AuthRepository(this.api);

  Future<void> login(String email, String password) async {
    try {
      final res = await api.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      // Backend kamu balas: { status: "error", message: ".." }
      if (res.statusCode != 200 || res.data['status'] == 'error') {
        throw res.data['message'] ?? 'Login gagal';
      }

      final token = res.data['token'];
      final refresh = res.data['refresh_token'];

      if (token == null || refresh == null) {
        throw 'Token tidak ditemukan pada response API';
      }

      await SecureStorage.saveTokens(accessToken: token, refreshToken: refresh);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw msg ?? 'Login gagal';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> tryRefreshToken() async {
    final refresh = await SecureStorage.getRefreshToken();
    if (refresh == null) return false;

    try {
      final res = await api.dio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );

      final newAccess = res.data['token'];
      final newRefresh = res.data['refresh_token'];

      if (newAccess == null || newRefresh == null) return false;

      await SecureStorage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await SecureStorage.clear();
  }
}
