import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/services/push_service.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Kartu "Notifikasi siap?" di Profil (Tahap 4). Memeriksa pengaturan HP yang
/// bisa membuat notifikasi — terutama alarm permintaan pengecekan foto — tidak
/// sampai atau tidak berbunyi, dengan tombol langsung ke pengaturannya.
/// Diperiksa ulang setiap kembali dari layar pengaturan.
class NotificationReadinessCard extends ConsumerStatefulWidget {
  const NotificationReadinessCard({super.key});

  @override
  ConsumerState<NotificationReadinessCard> createState() => _NotificationReadinessCardState();
}

class _NotificationReadinessCardState extends ConsumerState<NotificationReadinessCard> with WidgetsBindingObserver {
  bool? _notifications;
  bool? _alarmChannel;
  bool? _fullScreen;
  bool? _battery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final results = await Future.wait([
      PushService.notificationsEnabled(),
      PushService.channelEnabled(PushService.channelAlarm),
      PushService.canUseFullScreenIntent(),
      PushService.ignoringBatteryOptimizations(),
    ]);
    if (!mounted) return;
    setState(() {
      _notifications = results[0];
      _alarmChannel = results[1];
      _fullScreen = results[2];
      _battery = results[3];
    });
  }

  @override
  Widget build(BuildContext context) {
    final receivesAlarm = canReceiveReminders(ref.watch(authProvider).held);
    if (!PushService.available) {
      return const SdmNote(
        icon: Icons.notifications_off_outlined,
        text: 'Versi app ini belum tersambung ke notifikasi push.',
      );
    }
    final items = [
      _Item(
        title: 'Izin notifikasi',
        okText: 'Diizinkan',
        badText: 'Belum diizinkan — notifikasi tidak akan muncul',
        ok: _notifications,
        action: 'Izinkan',
        onFix: PushService.requestNotifications,
      ),
      if (receivesAlarm) ...[
        _Item(
          title: 'Alarm pengecekan foto',
          okText: 'Menyala',
          badText: 'Dimatikan — permintaan foto tidak berbunyi',
          ok: _alarmChannel,
          action: 'Nyalakan',
          onFix: () => PushService.openChannelSettings(PushService.channelAlarm),
        ),
        _Item(
          title: 'Tampil di layar terkunci',
          okText: 'Diizinkan',
          badText: 'Belum diizinkan — alarm hanya muncul di bilah notifikasi',
          ok: _fullScreen,
          action: 'Izinkan',
          onFix: PushService.openFullScreenIntentSettings,
        ),
      ],
      _Item(
        title: 'Penghemat baterai',
        okText: 'App ini dikecualikan',
        badText: 'Bisa menahan notifikasi saat HP tidak dipakai',
        ok: _battery,
        action: 'Kecualikan',
        onFix: PushService.requestIgnoreBatteryOptimizations,
      ),
    ];
    final allOk = items.every((i) => i.ok == true);

    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allOk ? Icons.notifications_active_outlined : Icons.notification_important_outlined,
                color: allOk ? const Color(0xFF15803D) : const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              Text(
                allOk ? 'Notifikasi siap' : 'Notifikasi siap?',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final i in items) _ItemRow(item: i),
          if (receivesAlarm) ...[
            const SizedBox(height: 4),
            const Text(
              'HP Xiaomi, Oppo, Vivo, dan Realme: nyalakan juga "Mulai otomatis" (Autostart) untuk app ini '
              'di pengaturan HP, supaya alarm tetap sampai saat app ditutup.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Item {
  final String title;
  final String okText;
  final String badText;
  final bool? ok;
  final String action;
  final Future<void> Function() onFix;
  const _Item({
    required this.title,
    required this.okText,
    required this.badText,
    required this.ok,
    required this.action,
    required this.onFix,
  });
}

class _ItemRow extends StatelessWidget {
  final _Item item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final ok = item.ok;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            ok == null ? Icons.more_horiz : (ok ? Icons.check_circle : Icons.error_outline),
            size: 20,
            color: ok == null ? AppTheme.textSecondary : (ok ? const Color(0xFF15803D) : AppTheme.danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                if (ok != null)
                  Text(ok ? item.okText : item.badText,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (ok == false) TextButton(onPressed: item.onFix, child: Text(item.action)),
        ],
      ),
    );
  }
}
