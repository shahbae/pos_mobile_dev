import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  static const _accessTokenKey = 'ACCESS_TOKEN';
  static const _refreshTokenKey = 'REFRESH_TOKEN';
  static const _rememberMeKey = 'REMEMBER_ME';

  static Stream<void> get changes => _changes.stream;

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
    _changes.add(null);
  }

  static Future<void> saveRememberMe(bool rememberMe) async {
    await _storage.write(key: _rememberMeKey, value: rememberMe.toString());
    _changes.add(null);
  }

  static Future<bool?> getRememberMe() async {
    final v = await _storage.read(key: _rememberMeKey);
    if (v == null) return null;
    return v.toLowerCase() == 'true';
  }

  static Future<void> clearRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
    _changes.add(null);
  }

  static Future<String?> getAccessToken() async =>
      _storage.read(key: _accessTokenKey);

  static Future<String?> getRefreshToken() async =>
      _storage.read(key: _refreshTokenKey);

  static Future<void> clear() async {
    await _storage.deleteAll();
    _changes.add(null);
  }
}
