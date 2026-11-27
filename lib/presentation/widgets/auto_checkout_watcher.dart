import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';

/// Absen pulang otomatis (revisi owner 26 Nov 2026): server menutup absen yang
/// lewat batas absen pulang kode shiftnya. App ini lalu keluar sendiri, supaya
/// HP outlet tidak tertinggal dalam sesi orang yang sudah pulang.
///
/// Dicek saat app kembali ke depan dan tiap 2 menit. Keluar HANYA bila status
/// terakhir yang diketahui di HP ini "bertugas" dan sekarang server bilang
/// absennya ditutup otomatis — jadi login ulang sesudahnya tidak ikut keluar
/// lagi (logout menghapus status tersimpan).
class AutoCheckoutWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const AutoCheckoutWatcher({super.key, required this.child});

  @override
  ConsumerState<AutoCheckoutWatcher> createState() => _AutoCheckoutWatcherState();
}

class _AutoCheckoutWatcherState extends ConsumerState<AutoCheckoutWatcher> with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_busy || !mounted) return;
    if (!mustCheckInToOpenShift(ref.read(authProvider).held)) return;
    _busy = true;
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final before = await AttendanceGateCache.read(today);
      if (before != AttendanceGateStatus.working) return;
      refreshMyDay(ref);
      final day = await ref.read(myDayProvider.future);
      if (day.onDuty || !day.autoCheckout || !mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Absen pulang otomatis'),
          content: const Text(
            'Absenmu sudah ditutup otomatis di batas absen pulang shift. Aplikasi keluar sekarang; '
            'masuk lagi bila masih perlu.',
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Oke')),
          ],
        ),
      );
      if (!mounted) return;
      await ref.read(authProvider.notifier).logout();
    } catch (_) {
      // Server tak terjangkau: coba lagi putaran berikutnya.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
