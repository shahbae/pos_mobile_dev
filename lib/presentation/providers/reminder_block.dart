import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/reminder_model.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';

/// Aturan layar blok reminder (uji manual 2 Nov 2026): reminder yang masuk
/// menutup seluruh app sampai diselesaikan. Tampilannya di `ReminderGate`.

/// Sisa waktu balas menurut jam server, dikurangi waktu sejak daftar diterima.
/// Jam HP yang salah tidak memengaruhinya. Null bila tidak bertenggat.
Duration? reminderTimeLeft(MyReminder r, MyReminderPage page, DateTime now) {
  final deadline = r.deadlineAt;
  if (deadline == null) return null;
  return deadline.difference(page.serverTime ?? page.receivedAt) - now.difference(page.receivedAt);
}

/// Reminder yang masih harus diselesaikan, urut giliran tampil: pengecekan
/// foto lebih dulu (tenggat terdekat), lalu catatan (terlama). Pengecekan yang
/// tenggatnya habis gugur di sini, tanpa menunggu jawaban server: HP yang
/// sinyalnya putus tidak boleh terkunci selamanya.
List<MyReminder> remindersToBlock(MyReminderPage? page, DateTime now) {
  if (page == null) return const [];
  final open = <MyReminder>[];
  for (final r in page.items) {
    if (!r.isPending) continue;
    if (r.isCheck) {
      final left = reminderTimeLeft(r, page, now);
      if (left == null || left <= Duration.zero) continue;
    }
    open.add(r);
  }
  int byTime(DateTime? a, DateTime? b) => (a ?? DateTime(0)).compareTo(b ?? DateTime(0));
  open.sort((a, b) {
    if (a.isCheck != b.isCheck) return a.isCheck ? -1 : 1;
    return a.isCheck ? byTime(a.deadlineAt, b.deadlineAt) : byTime(a.createdAt, b.createdAt);
  });
  return open;
}

/// Apakah blok boleh tampil di sesi ini. Salah bila:
/// - akun ini bukan penerima reminder;
/// - daftar reminder belum terbaca atau tarikan terakhirnya gagal (server tak
///   terjangkau, APK ditolak 426): foto tidak bisa terkirim, jadi blok hanya
///   akan menghentikan jualan offline dan menutupi dialog wajib update;
/// - sinyal putus menurut mode offline POS;
/// - orangnya sedang izin keluar: ia tidak di outlet, dan blok akan
///   menghalanginya menekan "Saya sudah kembali".
///
/// Selama status izin keluar belum terbaca, ia dianggap tidak sedang keluar.
final reminderBlockAllowedProvider = Provider<bool>((ref) {
  final held = ref.watch(authProvider).held;
  if (!canReceiveReminders(held)) return false;
  final pending = ref.watch(pendingRemindersProvider);
  if (pending.hasError || !pending.hasValue) return false;
  if (!ref.watch(offlineProvider.select((s) => s.reachable))) return false;
  if (pending.requireValue.items.isEmpty || !canLeaveOut(held)) return true;

  final open = ref.watch(myDayProvider).valueOrNull?.openAttendance;
  if (open == null) return true;
  final rows = ref.watch(onDutyProvider(isOwnerLevel(held) ? open.branchId : null)).valueOrNull;
  return !(rows ?? const []).any((r) => r.attendanceId == open.id && r.leaveOutId != null);
});

/// Pembayaran yang sedang berjalan menahan blok. Mengikuti umur halamannya,
/// lihat [ReminderPaymentHold]. Bukan provider: dipegang dari `initState` dan
/// `dispose`, saat provider tidak boleh diubah.
class ReminderHold {
  ReminderHold._();

  static final count = ValueNotifier<int>(0);
  static bool get held => count.value > 0;
}

/// Dipasang di State halaman pembayaran (Checkout, QRIS, Transaksi Berhasil).
/// Pelanggan masih di depan kasir sampai halaman terakhirnya ditutup, jadi
/// blok baru muncul sesudah itu. Alarm tetap berbunyi selama menunggu.
mixin ReminderPaymentHold<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    ReminderHold.count.value++;
  }

  @override
  void dispose() {
    ReminderHold.count.value--;
    super.dispose();
  }
}
