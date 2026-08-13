import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Pesan error lokasi yang sudah diterjemahkan, agar bisa ditampilkan ke user.
class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}

class LocationHelper {
  /// Ambil koordinat GPS terkini. Menangani service mati + izin ditolak.
  static Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'Layanan lokasi (GPS) mati. Aktifkan lokasi lalu coba lagi.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationException('Izin lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Izin lokasi diblokir permanen. Aktifkan lewat pengaturan aplikasi.',
      );
    }

    // Akurasi tinggi mengandalkan satelit. Di dalam ruangan sinyalnya sering
    // tidak pernah dapat fix, dan tanpa batas waktu panggilan ini menggantung
    // selamanya — overlay absensi berhenti di "Mendeteksi lokasi…" dan kasir
    // membacanya sebagai gagal. Jadi dibatasi waktunya, lalu diturunkan ke
    // akurasi sedang yang memakai wifi/menara seluler dan biasanya dapat di
    // dalam ruangan.
    final position = await _tryFix(LocationAccuracy.high) ??
        await _tryFix(LocationAccuracy.medium);
    if (position != null) {
      return position;
    }

    // Sengaja TIDAK jatuh ke getLastKnownPosition: koordinat basi bisa berasal
    // dari lokasi lain dan akan tercatat sebagai absen yang sah di cabang.
    throw LocationException(
      'Lokasi tidak terdeteksi. Coba dekat jendela atau keluar sebentar ke '
      'area terbuka, lalu ulangi.',
    );
  }

  static const _fixTimeout = Duration(seconds: 12);

  /// Satu percobaan ambil koordinat. Mengembalikan null bila waktunya habis,
  /// supaya pemanggil bisa mencoba akurasi yang lebih rendah.
  static Future<Position?> _tryFix(LocationAccuracy accuracy) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: _fixTimeout,
        ),
      );
    } on TimeoutException {
      return null;
    }
  }
}
