import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_detail_page.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_list_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';

/// Spanduk "reminder belum dibalas" di semua tab Dashboard (Tahap 4). Jaring
/// pengaman bila notifikasinya tidak sampai atau terlanjur digeser: datanya
/// ditarik ulang tiap app dibuka. Hilang sendiri begitu semuanya dibalas.
class PendingReminderBanner extends ConsumerWidget {
  const PendingReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canReceiveReminders(ref.watch(authProvider).held)) return const SizedBox.shrink();
    final items = ref.watch(pendingRemindersProvider).valueOrNull?.items ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    final checks = items.where((r) => r.isCheck).length;
    final text = checks > 0
        ? '$checks permintaan foto menunggu${items.length > checks ? ' · ${items.length - checks} catatan' : ''}'
        : '${items.length} catatan belum dibaca';
    final color = checks > 0 ? const Color(0xFFB91C1C) : const Color(0xFF1D4ED8);

    return Material(
      color: color,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => items.length == 1 ? ReminderDetailPage(reminderId: items.first.id) : const ReminderListPage(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(checks > 0 ? Icons.photo_camera_outlined : Icons.campaign_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const Text('Buka', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
