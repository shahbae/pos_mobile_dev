import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan konfigurasi printer default (MAC, nama, auto-print).
/// Terpisah dari SecureStorage token agar tidak memicu stream auth.
class PrinterPrefs {
  static const _storage = FlutterSecureStorage();

  static const _macKey = 'PRINTER_MAC';
  static const _nameKey = 'PRINTER_NAME';
  static const _autoKey = 'PRINTER_AUTOPRINT';

  static Future<void> saveDefault({required String mac, required String name}) async {
    await _storage.write(key: _macKey, value: mac);
    await _storage.write(key: _nameKey, value: name);
  }

  static Future<void> clearDefault() async {
    await _storage.delete(key: _macKey);
    await _storage.delete(key: _nameKey);
  }

  static Future<String?> getMac() => _storage.read(key: _macKey);
  static Future<String?> getName() => _storage.read(key: _nameKey);

  static Future<void> setAutoPrint(bool value) =>
      _storage.write(key: _autoKey, value: value.toString());

  /// Default ON bila belum pernah diset.
  static Future<bool> getAutoPrint() async {
    final v = await _storage.read(key: _autoKey);
    return v == null ? true : v.toLowerCase() == 'true';
  }
}
