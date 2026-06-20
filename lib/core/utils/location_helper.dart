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

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
