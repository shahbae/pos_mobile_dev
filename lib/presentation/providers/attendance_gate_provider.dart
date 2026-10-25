import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';

/// Keadaan absensi yang menentukan apakah aplikasi terbuka (revisi 17 Okt 2026).
enum AttendanceGateStatus {
  /// Belum absen masuk — yang terbuka hanya halaman Absensi. Dobel shift:
  /// juga di antara pulang shift pertama dan masuk shift berikutnya.
  notCheckedIn,

  /// Sudah absen masuk, belum pulang — aplikasi terbuka.
  working,

  /// Sudah absen pulang dan tidak ada shift lagi hari ini — terkunci sampai besok.
  checkedOut,
}

AttendanceGateStatus gateStatusOf(AttendanceModel? att) {
  if (att == null || !att.hasCheckedIn) return AttendanceGateStatus.notCheckedIn;
  if (att.hasCheckedOut) return AttendanceGateStatus.checkedOut;
  return AttendanceGateStatus.working;
}

/// Tahap 1 SDM: terkunci sesudah absen pulang hanya bila tidak ada shift lagi.
AttendanceGateStatus gateStatusOfDay(MyDay day) {
  if (day.openAttendance != null) return AttendanceGateStatus.working;
  if (day.hasAttendance && !day.hasNextShift) return AttendanceGateStatus.checkedOut;
  return AttendanceGateStatus.notCheckedIn;
}

/// Status terakhir yang diketahui, per tanggal. Dipakai saat server tidak bisa
/// dihubungi — mati listrik di outlet adalah alasan jualan offline ada, dan
/// absensi yang tidak bisa dicek tidak boleh ikut menghentikan jualan.
///
/// Disimpan di secure storage yang sama dengan token: logout menghapus
/// semuanya (`deleteAll`), jadi status satu akun tidak terbawa ke akun lain.
class AttendanceGateCache {
  static const _storage = FlutterSecureStorage();
  static const _key = 'ATTENDANCE_GATE';

  static Future<void> write(String date, AttendanceGateStatus s) =>
      _storage.write(key: _key, value: '$date|${s.name}');

  static Future<AttendanceGateStatus?> read(String date) async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 2 || parts[0] != date) return null;
    for (final s in AttendanceGateStatus.values) {
      if (s.name == parts[1]) return s;
    }
    return null;
  }
}

/// Dibaca ulang saat aplikasi kembali ke depan, sesudah absen masuk/pulang,
/// dan saat ditekan "Muat ulang" (semuanya lewat [myDayProvider]). Gagal
/// menghubungi server → status terakhir hari ini; belum pernah ada → aplikasi
/// tetap dibuka (lihat [AttendanceGateCache]).
final attendanceGateProvider = FutureProvider<AttendanceGateStatus>((ref) async {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  try {
    final day = await ref.watch(myDayProvider.future);
    final status = gateStatusOfDay(day);
    await AttendanceGateCache.write(today, status);
    return status;
  } catch (_) {
    return await AttendanceGateCache.read(today) ?? AttendanceGateStatus.working;
  }
});
