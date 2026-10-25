import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';

/// Tugas kasir hari ini di [branchId]: true = ada shift bertugas kasir (atau
/// kasir & penyaji), false = semua shift di sana bertugas penyaji, null = tidak
/// ada jadwal di cabang itu. Cerminan `CrewMayWork` di BE.
bool? cashierDutyOf(MyDay day, int? branchId) {
  final here = day.shiftsAtBranch(branchId);
  if (here.isEmpty) return null;
  return here.any((s) => ScheduleDuty.holdsCashier(s.duty));
}

/// Tugas terakhir yang diketahui, per tanggal dan cabang — supaya POS tetap
/// terbuka (atau tetap tertutup) saat jualan offline. Logout menghapusnya
/// bersama token.
class DutyCache {
  static const _storage = FlutterSecureStorage();
  static const _key = 'CASHIER_DUTY';

  static Future<void> write(String date, int? branchId, bool? duty) =>
      _storage.write(key: _key, value: '$date|${branchId ?? ''}|${duty ?? ''}');

  static Future<bool?> read(String date, int? branchId) async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3 || parts[0] != date || parts[1] != '${branchId ?? ''}') return null;
    return parts[2] == 'true' ? true : (parts[2] == 'false' ? false : null);
  }
}

/// Tugas kasir hari ini untuk karyawan yang menunya mengikuti tugas. Role lain
/// tidak pernah dibaca (null), jadi tidak ada permintaan tambahan untuk mereka.
final cashierDutyProvider = FutureProvider<bool?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!isDutyGated(auth.held)) return null;
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  try {
    final day = await ref.watch(myDayProvider.future);
    final duty = cashierDutyOf(day, auth.branchId);
    await DutyCache.write(today, auth.branchId, duty);
    return duty;
  } catch (_) {
    return DutyCache.read(today, auth.branchId);
  }
});

/// Fitur yang terbuka hari ini. Selama tugas belum terbaca, menu tidak
/// dikurangi: server tetap menolak POS untuk penyaji.
final todayFeaturesProvider = Provider<Set<AppFeature>>((ref) {
  final auth = ref.watch(authProvider);
  final duty = ref.watch(cashierDutyProvider).valueOrNull;
  return featuresForToday(auth.role, auth.held, cashierDuty: duty);
});
