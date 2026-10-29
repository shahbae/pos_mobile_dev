import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/reminder_model.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_detail_page.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _clock = DateFormat('HH.mm', 'id_ID');
final _when = DateFormat('EEE d MMM, HH.mm', 'id_ID');

/// Reminder milik akun ini (Tahap 4): yang belum dibalas di atas, lalu
/// riwayat. Reminder dikirim SPV atau leader dari web admin ke kru yang
/// sedang bertugas.
class ReminderListPage extends ConsumerWidget {
  const ReminderListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRemindersProvider);
    final history = ref.watch(reminderHistoryProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final pendingIds = {for (final r in pending.valueOrNull?.items ?? const <MyReminder>[]) r.id};

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Reminder'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshReminders(ref);
          await ref.read(reminderHistoryProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
          children: [
            const _Heading('Belum dibalas'),
            const SizedBox(height: 8),
            ...pending.when(
              loading: () => const [Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))],
              error: (e, _) => [SdmNote(icon: Icons.error_outline, text: '$e', warning: true)],
              data: (page) => page.items.isEmpty
                  ? const [SdmNote(icon: Icons.check_circle_outline, text: 'Tidak ada reminder yang menunggu balasanmu.')]
                  : [
                      for (final r in page.items) ...[
                        _ReminderCard(r: r),
                        const SizedBox(height: 8),
                      ],
                    ],
            ),
            const SizedBox(height: 16),
            const _Heading('Riwayat'),
            const SizedBox(height: 8),
            ...history.when(
              loading: () => const [Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))],
              error: (e, _) => [SdmNote(icon: Icons.error_outline, text: '$e', warning: true)],
              data: (page) {
                // Yang masih menunggu sudah tampil di atas.
                final rows = page.items.where((r) => !pendingIds.contains(r.id)).toList();
                if (rows.isEmpty) {
                  return const [SdmEmpty(icon: Icons.campaign_outlined, message: 'Belum ada reminder.')];
                }
                return [
                  for (final r in rows) ...[
                    _ReminderCard(r: r),
                    const SizedBox(height: 8),
                  ],
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary));
}

class _ReminderCard extends StatelessWidget {
  final MyReminder r;
  const _ReminderCard({required this.r});

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (r.createdAt != null) _when.format(r.createdAt!.toLocal()),
      r.senderName,
      if (r.isCheck && r.isPending && r.deadlineAt != null) 'batas ${_clock.format(r.deadlineAt!.toLocal())}',
      if (r.isCheck) '${r.photographed}/${r.parts.length} foto',
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReminderDetailPage(reminderId: r.id)),
      ),
      child: SdmCard(
        child: Row(
          children: [
            Icon(r.isCheck ? Icons.photo_camera_outlined : Icons.campaign_outlined, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.message.isNotEmpty ? r.message : (r.isCheck ? 'Pengecekan foto' : 'Catatan'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SdmPill(reminderStatusLabels[r.status] ?? r.status, color: reminderStatusColor(r.status)),
          ],
        ),
      ),
    );
  }
}
