import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Nama dan versi app ini, dikirim ke be-pos di setiap permintaan API
/// (wajib update, 24 Okt 2026). Server menolak versi di bawah rilis wajib
/// dengan 426, dan [upgradeRequired] memberi tahu penjaga pembaruan.
class AppIdentity {
  AppIdentity._();

  /// Nama app di katalog rilis be-pos (`app_releases.app`).
  static const name = 'kasir';

  /// versionCode APK terpasang — angka setelah `+` di `pubspec.yaml`. 0 sampai
  /// [load] selesai.
  static int versionCode = 0;

  /// versionName APK terpasang (mis. `1.0.18`), dicatat be-pos bersama token
  /// notifikasi push. Kosong sampai [load] selesai.
  static String versionName = '';

  /// Bertambah setiap server membalas 426, supaya `AppUpdateGate` memeriksa
  /// ulang dan memunculkan dialog wajib di layar mana pun yang sedang terbuka.
  static final upgradeRequired = ValueNotifier<int>(0);

  /// Dipanggil sekali di `main()`, sebelum permintaan API pertama.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      versionCode = int.tryParse(info.buildNumber) ?? 0;
      versionName = info.version;
    } catch (_) {
      // Tanpa versi, server menganggapnya versi 0. Itu hanya berarti dialog
      // wajib muncul bila ada rilis wajib — tidak ada yang rusak.
    }
  }

  static Map<String, String> get headers => {
    'X-App-Name': name,
    'X-App-Version-Code': '$versionCode',
  };
}
