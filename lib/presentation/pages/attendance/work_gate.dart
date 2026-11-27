import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/presentation/pages/attendance/attendance_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Lima menu kerja outlet yang dikunci sebelum absen masuk (revisi owner 26 Nov
/// 2026): Kasir, Audit Stok, Catat Waste, Retur Stok, Ceklis Foto. Owner bebas;
/// selain owner tidak ada pengecualian. Menu Kasir juga mengikuti posisi hari
/// itu: penyaji tidak boleh, kasir dan penyaji kasir boleh. Cermin DutyGate di
/// server (403 check_in_required / not_cashier_today).
const kWorkMenuNeedCheckIn = 'Absen masuk dulu sebelum memakai menu ini.';
const kWorkMenuNotCashier = 'Hari ini kamu bertugas sebagai penyaji. Menu Kasir hanya untuk posisi kasir atau penyaji kasir.';

/// Keputusan murni (dipakai juga di tes): null = boleh, selain itu pesannya.
/// [day] null = server tak terjangkau; [status] dari kunci absensi (sudah
/// memakai status terakhir yang diketahui saat offline).
String? workMenuBlock({
  required Iterable<String> held,
  required AttendanceGateStatus status,
  required MyDay? day,
  required bool cashier,
}) {
  if (!mustCheckInToOpenShift(held)) return null;
  if (status != AttendanceGateStatus.working) return kWorkMenuNeedCheckIn;
  if (cashier && day?.currentDuty == 'server') return kWorkMenuNotCashier;
  return null;
}

/// Pastikan orang ini boleh membuka menu kerja. Mengembalikan true bila boleh;
/// bila tidak, menampilkan alasannya (dengan jalan ke Absensi bila belum absen).
Future<bool> ensureOnDuty(BuildContext context, WidgetRef ref, {bool cashier = false}) async {
  final held = ref.read(authProvider).held;
  if (!mustCheckInToOpenShift(held)) return true;
  // Baca ulang: absen bisa saja sudah ditutup otomatis, atau akun lain baru
  // masuk di HP yang sama.
  ref.invalidate(myDayProvider);
  MyDay? day;
  try {
    day = await ref.read(myDayProvider.future);
  } catch (_) {
    day = null;
  }
  final status = day != null ? gateStatusOfDay(day) : await ref.read(attendanceGateProvider.future);
  final block = workMenuBlock(held: held, status: status, day: day, cashier: cashier);
  if (block == null) return true;
  if (!context.mounted) return false;
  final needCheckIn = block == kWorkMenuNeedCheckIn;
  final goAbsen = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(needCheckIn ? 'Belum absen masuk' : 'Bukan posisi kasir'),
      content: Text(block),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(needCheckIn ? 'Nanti' : 'Tutup')),
        if (needCheckIn)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Absen Masuk'),
          ),
      ],
    ),
  );
  if (goAbsen == true && context.mounted) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendancePage()));
  }
  return false;
}
