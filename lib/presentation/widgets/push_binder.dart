import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/data/services/push_service.dart';
import 'package:pos_mobile/presentation/pages/help/help_ticket_detail_page.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_detail_page.dart';
import 'package:pos_mobile/presentation/pages/schedules/my_schedule_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';

/// Web admin sesuai flavor, tujuan ketukan `web:/…` (kontrak push be-pos).
String get webBaseUrl => appFlavor == 'prod' ? 'https://app.estehcandi.com' : 'https://app-dev.estehcandi.com';

/// Menyambungkan notifikasi push dengan sesi yang sedang login (Tahap 4).
///
/// - Mendaftarkan token ke be-pos saat sesi mulai dan tiap app kembali ke
///   depan (memperbarui `last_seen_at`).
/// - Menyegarkan reminder yang belum dibalas pada saat yang sama, dan tiap
///   notifikasi masuk — jaring pengaman bila notifikasinya tidak sampai.
/// - Membuka tujuan ketukan notifikasi. Dipasang di bawah `MaterialApp`,
///   jadi `Navigator.of(context)` adalah navigator sesi ini; navigator sesi
///   sebelumnya (berganti tiap login/logout) tidak pernah tersentuh.
class PushBinder extends ConsumerStatefulWidget {
  final Widget child;
  const PushBinder({super.key, required this.child});

  @override
  ConsumerState<PushBinder> createState() => _PushBinderState();
}

class _PushBinderState extends ConsumerState<PushBinder> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushService.pendingTarget.addListener(_openPending);
    PushService.received.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _register();
      _openPending();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushService.pendingTarget.removeListener(_openPending);
    PushService.received.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _register();
      _refresh();
    }
  }

  void _register() => PushService.register(ref.read(apiProvider));

  void _refresh() {
    if (canReceiveReminders(ref.read(authProvider).held)) ref.invalidate(pendingRemindersProvider);
  }

  void _openPending() {
    final target = PushService.pendingTarget.value;
    if (target == null || !mounted) return;
    PushService.pendingTarget.value = null;
    openPushTarget(context, target);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Buka tujuan ketukan notifikasi. `app:/…` di dalam app, `web:/…` di
/// browser. Tujuan yang tidak dikenal diabaikan: app lama tidak boleh macet
/// karena server menambah jenis notifikasi baru.
Future<void> openPushTarget(BuildContext context, String target) async {
  if (target.startsWith('web:')) {
    await launchUrl(Uri.parse('$webBaseUrl${target.substring(4)}'), mode: LaunchMode.externalApplication);
    return;
  }
  final path = target.startsWith('app:') ? target.substring(4) : target;
  final segments = Uri.parse(path).pathSegments;
  if (segments.isEmpty) return;
  final id = segments.length > 1 ? int.tryParse(segments[1]) : null;
  final Widget? page = switch (segments.first) {
    'reminders' when id != null => ReminderDetailPage(reminderId: id),
    'help-tickets' when id != null => HelpTicketDetailPage(ticketId: id),
    'schedule' => const MySchedulePage(),
    _ => null,
  };
  if (page == null) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}
