import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/reminder_model.dart';
import 'package:pos_mobile/data/services/push_service.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_detail_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/reminder_block.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';

/// Menahan tombol Back selama blok tampil.
///
/// Lapisan blok berada di luar Navigator, jadi `PopScope` tidak berlaku dan
/// Back akan menutup halaman di belakangnya tanpa terlihat. Pengamat ini harus
/// didaftarkan di `main()` sebelum `runApp`: Back ditawarkan menurut urutan
/// daftar, dan ia harus mendahului pengamat milik `MaterialApp`.
class ReminderBackGuard with WidgetsBindingObserver {
  ReminderBackGuard._();

  static final instance = ReminderBackGuard._();
  static bool blocking = false;

  @override
  Future<bool> didPopRoute() async => blocking;
}

/// Layar blok reminder (uji manual 2 Nov 2026): reminder yang belum
/// diselesaikan menutup seluruh app sampai selesai atau tenggatnya habis.
///
/// Sengaja lapisan di atas Navigator, bukan halaman yang di-push. `pop` dan
/// `pushReplacement` selalu mengenai halaman teratas, jadi halaman blok akan
/// tertutup oleh pekerjaan halaman di belakangnya, misalnya QRIS yang lunas.
/// Dengan lapisan, tumpukan halaman tidak tersentuh dan kembali utuh.
class ReminderGate extends ConsumerStatefulWidget {
  final Widget child;
  final DateTime Function() now;

  const ReminderGate({super.key, required this.child, this.now = DateTime.now});

  @override
  ConsumerState<ReminderGate> createState() => _ReminderGateState();
}

class _ReminderGateState extends ConsumerState<ReminderGate> {
  int? _currentId;
  Timer? _expiry;
  bool _rebuildQueued = false;

  /// Pengecekan yang alarmnya mungkin masih berbunyi.
  final _checks = <int>{};

  @override
  void initState() {
    super.initState();
    ReminderHold.count.addListener(_queueRebuild);
  }

  @override
  void dispose() {
    ReminderHold.count.removeListener(_queueRebuild);
    ReminderBackGuard.blocking = false;
    _expiry?.cancel();
    super.dispose();
  }

  /// Penahan berubah dari `initState`/`dispose` halaman, saat pohon widget
  /// sedang dibangun atau dikunci, jadi `setState` menunggu frame selesai.
  void _queueRebuild() {
    if (_rebuildQueued) return;
    _rebuildQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rebuildQueued = false;
      if (mounted) setState(() {});
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Berjaga atas daftar terbaru: alarm pengecekan yang tak lagi bisa dibalas
  /// dihentikan (tidak ada lagi yang bisa dikerjakan orangnya, termasuk bila
  /// tenggatnya habis selama pembayaran), dan blok dibangun ulang tepat saat
  /// tenggat terdekat habis.
  void _watch(MyReminderPage? page, List<MyReminder> open, DateTime now) {
    final checks = {for (final r in open) if (r.isCheck) r.id};
    for (final id in _checks.difference(checks)) {
      unawaited(PushService.cancelTag('reminder-$id'));
    }
    _checks
      ..clear()
      ..addAll(checks);

    _expiry?.cancel();
    _expiry = null;
    Duration? soonest;
    for (final r in open) {
      final left = page == null ? null : reminderTimeLeft(r, page, now);
      if (left != null && (soonest == null || left < soonest)) soonest = left;
    }
    if (soonest != null) {
      _expiry = Timer(soonest + const Duration(milliseconds: 200), () {
        if (mounted) setState(() {});
      });
    }
  }

  /// Yang sedang tampil dibiarkan sampai selesai, walau ada kiriman baru yang
  /// giliran tampilnya lebih dulu.
  MyReminder? _pick(List<MyReminder> open) {
    for (final r in open) {
      if (r.id == _currentId) return r;
    }
    _currentId = open.isEmpty ? null : open.first.id;
    return open.isEmpty ? null : open.first;
  }

  @override
  Widget build(BuildContext context) {
    final receives = canReceiveReminders(ref.watch(authProvider).held);
    final page = receives ? ref.watch(pendingRemindersProvider).valueOrNull : null;
    final now = widget.now();
    final open = remindersToBlock(page, now);
    _watch(page, open, now);

    final allowed = ref.watch(reminderBlockAllowedProvider);
    final current = allowed && !ReminderHold.held ? _pick(open) : null;
    final blocking = current != null;
    ReminderBackGuard.blocking = blocking;

    // Susunannya tetap sama saat blok tampil maupun tidak, supaya Navigator
    // dan seluruh halamannya tidak pernah dibangun ulang.
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: blocking,
          // Keyboard halaman di belakang ikut tertutup.
          child: ExcludeFocus(excluding: blocking, child: widget.child),
        ),
        if (current != null)
          ReminderDetailPage(
            key: ValueKey('reminder-gate-${current.id}'),
            reminderId: current.id,
            blocking: true,
            initial: current,
            initialAt: page?.receivedAt,
          ),
      ],
    );
  }
}
