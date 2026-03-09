import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'ACCESS_TOKEN';
  static const _refreshTokenKey = 'REFRESH_TOKEN';

  static Future<bool> hasTokens() async {
    final a = await getAccessToken();
    return a != null;
  }

  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  static Future<String?> getAccessToken() async =>
      _storage.read(key: _accessTokenKey);

  static Future<String?> getRefreshToken() async =>
      _storage.read(key: _refreshTokenKey);

  static Future<void> clear() async {
    await _storage.deleteAll();
  }
}
