import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan konfigurasi printer default (MAC, nama, auto-print).
/// Terpisah dari SecureStorage token agar tidak memicu stream auth.
class PrinterPrefs {
  static const _storage = FlutterSecureStorage();

  static const _macKey = 'PRINTER_MAC';
  static const _nameKey = 'PRINTER_NAME';
  static const _autoKey = 'PRINTER_AUTOPRINT';
  static const _drawerKey = 'PRINTER_OPEN_DRAWER';
  static const _drawerPinKey = 'PRINTER_DRAWER_PIN';
  static const _cutterKey = 'PRINTER_HAS_CUTTER';

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

  static Future<void> setOpenDrawer(bool value) =>
      _storage.write(key: _drawerKey, value: value.toString());

  /// Default OFF — hanya dinyalakan bila laci kas memang terpasang.
  static Future<bool> getOpenDrawer() async {
    final v = await _storage.read(key: _drawerKey);
    return v?.toLowerCase() == 'true';
  }

  /// Pin kick laci: 2 (umum) atau 5.
  static Future<void> setDrawerPin(int pin) =>
      _storage.write(key: _drawerPinKey, value: pin.toString());

  static Future<int> getDrawerPin() async {
    final v = await _storage.read(key: _drawerPinKey);
    return v == '5' ? 5 : 2;
  }

  static Future<void> setHasCutter(bool value) =>
      _storage.write(key: _cutterKey, value: value.toString());

  /// Default OFF. Printer bluetooth mini/portable hampir semuanya tidak punya
  /// pemotong kertas, dan firmware-nya sering menerjemahkan perintah potong
  /// (GS V) sebagai "majukan kertas ke posisi pemotong" — kertas keluar panjang
  /// tanpa terpotong. Jadi perintah potong hanya dikirim bila dinyalakan manual.
  static Future<bool> getHasCutter() async {
    final v = await _storage.read(key: _cutterKey);
    return v?.toLowerCase() == 'true';
  }
}
