import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_mobile/data/models/me_model.dart';
import 'package:pos_mobile/data/services/api_services.dart';
import '../services/secure_storage.dart';

/// Hasil mencoba memperbarui access token.
enum RefreshOutcome {
  /// Token baru tersimpan.
  refreshed,

  /// Server menjawab dan menolak: sesi memang sudah tidak sah.
  rejected,

  /// Server tidak menjawab (jaringan putus). Sesinya belum tentu tidak sah.
  unreachable,
}

class AuthRepository {
  final ApiService api;

  AuthRepository(this.api);

  /// Ambil identitas user aktif dari `GET /me` (role & branch otoritatif dari BE).
  Future<MeModel> getMe() async {
    final res = await api.dio.get('/me');
    if (res.statusCode != 200 || res.data['success'] != true) {
      final msg = res.data['message'] ?? res.data['error'] ?? 'Gagal memuat profil';
      throw msg;
    }
    final data = res.data['data'];
    if (data is! Map) throw 'Data profil tidak ditemukan';
    return MeModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> login(
    String email,
    String password, {
    required bool rememberMe,
  }) async {
    try {
      final res = await api.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password, 'remember_me': rememberMe},
      );

      // API response: { success: true/false, data: { access_token, ... } }
      if (res.statusCode != 200 || res.data['success'] != true) {
        final msg = res.data['message'] ?? res.data['error'] ?? 'Login gagal';
        throw msg;
      }

      final data = res.data['data'];
      final token = data['access_token'];
      final refreshToken = data['refresh_token'];

      if (token == null) {
        throw 'Token tidak ditemukan pada response API';
      }

      await SecureStorage.saveTokens(
        accessToken: token,
        refreshToken: rememberMe ? refreshToken : null,
      );
      await SecureStorage.saveRememberMe(rememberMe);
      if (!rememberMe) {
        await SecureStorage.clearRefreshToken();
      }

      if (kDebugMode) {
        final hasAccess = await SecureStorage.getAccessToken() != null;
        final hasRefresh = await SecureStorage.getRefreshToken() != null;
        debugPrint(
          'Auth login ok | rememberMe=$rememberMe | accessSaved=$hasAccess | refreshSaved=$hasRefresh',
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw msg ?? 'Login gagal';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<RefreshOutcome> tryRefreshToken() async {
    final refresh = await SecureStorage.getRefreshToken();
    if (refresh == null) return RefreshOutcome.rejected;

    try {
      final res = await api.dio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );

      if (res.data['success'] != true) return RefreshOutcome.rejected;

      final data = res.data['data'];
      final newAccess = data?['access_token'];

      if (newAccess == null) return RefreshOutcome.rejected;

      await SecureStorage.saveTokens(
        accessToken: newAccess,
        refreshToken: data?['refresh_token'],
      );

      return RefreshOutcome.refreshed;
    } on DioException catch (e) {
      // Ada jawaban = server menolak. Tanpa jawaban = timeout / koneksi putus,
      // refresh token-nya belum tentu tidak sah.
      return e.response == null ? RefreshOutcome.unreachable : RefreshOutcome.rejected;
    } catch (_) {
      return RefreshOutcome.rejected;
    }
  }

  Future<void> logout() async {
    final refreshToken = await SecureStorage.getRefreshToken();

    try {
      final res = await api.dio.post(
        '/auth/logout',
        data: refreshToken != null ? {'refresh_token': refreshToken} : {},
      );

      if (res.statusCode == 405) {
        await api.dio.get('/auth/logout');
      }
    } catch (e) {
      final _ = e;
    } finally {
      await SecureStorage.clear();
    }
  }
}
