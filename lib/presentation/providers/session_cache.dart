import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/daily_report_provider.dart';
import 'package:pos_mobile/presentation/providers/dashboard_index_provider.dart';
import 'package:pos_mobile/presentation/providers/dashboard_operational_provider.dart';
import 'package:pos_mobile/presentation/providers/help_provider.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';

/// Data yang hanya berlaku selama satu sesi login (revisi uji manual 31 Okt
/// 2026, pola yang sama dengan app gudang).
///
/// Dulu cache hanya dibuang saat pindah cabang. Sesudah logout lalu login akun
/// lain di HP yang sama, hari saya, kunci absen, dan tugas kasir/penyaji akun
/// sebelumnya masih tampil, dan app mencoba memindahkan akun baru ke cabang
/// akun lama (403).
///
/// Data yang terikat cabang sudah ikut dibuang lewat [branchScopeProvider].
/// Yang ditulis di sini adalah sisanya: milik orangnya, bukan cabangnya.
/// Turunannya (kunci absen, tugas kasir, cabang aktif) tidak perlu disebut,
/// karena Riverpod menghitungnya ulang begitu sumbernya dibuang.
///
/// Sengaja TIDAK ikut dibuang:
/// - antrean jualan offline: milik perangkat, uangnya sudah di laci, dan harus
///   tetap terunggah siapa pun yang login berikutnya;
/// - konfigurasi printer dan status update app: milik perangkat.
///
/// Daftar ini ditulis satu per satu, bukan disapu otomatis: provider baru yang
/// menyimpan data milik orang harus ditambahkan di sini secara sadar.
final List<ProviderOrFamily> _sessionProviders = [
  // Cabang & jadwal milik orang ini
  branchListProvider,
  mySchedulesProvider,
  myProfileProvider,

  // Reminder & bantuan
  pendingRemindersProvider,
  reminderHistoryProvider,
  myHelpTicketsProvider,
  helpCategoriesProvider,

  // Penyaring layar
  dashboardIndexProvider,
  dashboardDateProvider,
  dailyReportDateProvider,
  leaderDailyReportRangeProvider,
  paymentsReportRangeProvider,
];

/// Melupakan seluruh data sesi: menaikkan [branchScope] (semua data yang
/// terikat cabang, termasuk hari saya, lahir ulang) lalu membuang sisanya.
///
/// Dipanggil saat logout, saat login berhasil, dan saat token hilang dari
/// storage (logout paksa dari server atau ganti password).
///
/// Menerima fungsi pembatal dan pengendali scope, bukan `Ref`, supaya bisa
/// diuji dengan `ProviderContainer` sungguhan.
void clearSessionCache(
  void Function(ProviderOrFamily) invalidate,
  StateController<int> branchScope,
) {
  branchScope.state++;
  for (final provider in _sessionProviders) {
    invalidate(provider);
  }
}
