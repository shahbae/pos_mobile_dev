import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/pages/attendance/attendance_page.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Mengunci aplikasi mengikuti absensi hari ini (revisi 17 Okt 2026).
///
/// Belum absen masuk → halaman Absensi saja. Sudah absen pulang → layar
/// terkunci sampai besok, kecuali masih ada shift lagi hari ini (dobel shift,
/// Tahap 1 SDM): kembali ke halaman Absensi. Di antaranya → [child]. Diperiksa ulang tiap
/// aplikasi kembali ke depan, supaya pergantian hari dan pembatalan absen
/// pulang oleh supervisor terbaca tanpa harus menutup aplikasi.
class AttendanceGate extends ConsumerStatefulWidget {
  final Widget child;
  const AttendanceGate({super.key, required this.child});

  @override
  ConsumerState<AttendanceGate> createState() => _AttendanceGateState();
}

class _AttendanceGateState extends ConsumerState<AttendanceGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Kunci dihitung dari hari saya; membaca ulang hari saya ikut menilai
      // ulang kunci dan tugas kasir/penyaji.
      ref.invalidate(myDayProvider);
      ref.invalidate(attendanceGateProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(attendanceGateProvider);
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Provider-nya tidak pernah gagal (jatuh ke status tersimpan), tapi
      // kalaupun gagal, aplikasi dibuka — jangan sampai jualan terhenti.
      error: (_, _) => widget.child,
      data: (s) {
        switch (s) {
          case AttendanceGateStatus.notCheckedIn:
            return const AttendancePage(
              isRoot: true,
              gateNotice: 'Absen masuk dulu untuk mulai bekerja. Menu lain '
                  'terbuka setelah absen masuk.',
            );
          case AttendanceGateStatus.checkedOut:
            return const CheckedOutLockPage();
          case AttendanceGateStatus.working:
            return widget.child;
        }
      },
    );
  }
}

/// Layar sesudah absen pulang.
class CheckedOutLockPage extends ConsumerWidget {
  const CheckedOutLockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Absensi'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.nightlight_round, size: 72, color: AppTheme.brandBlue),
          const SizedBox(height: 16),
          const Text(
            'Kamu sudah absen pulang hari ini',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aplikasi terbuka lagi besok setelah absen masuk.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Salah tekan absen pulang? Minta supervisor atau owner '
              'membatalkannya di web admin (menu Absensi), lalu tekan Muat ulang.',
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              ref.invalidate(myDayProvider);
              ref.invalidate(attendanceGateProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Muat ulang'),
          ),
        ],
      ),
    );
  }
}
