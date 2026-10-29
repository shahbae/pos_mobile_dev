import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/help_ticket_model.dart';
import 'package:pos_mobile/presentation/pages/help/help_ticket_detail_page.dart';
import 'package:pos_mobile/presentation/pages/help/help_ticket_form_page.dart';
import 'package:pos_mobile/presentation/providers/help_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _day = DateFormat('EEE d MMM', 'id_ID');
final _due = DateFormat('EEE d MMM, HH.mm', 'id_ID');

/// Warna status tiket, sama dengan web admin.
Color helpStatusColor(String status) => switch (status) {
  'submitted' => const Color(0xFFD97706),
  'approved' => const Color(0xFF0369A1),
  'resolved' => const Color(0xFF7C3AED),
  'confirmed' => const Color(0xFF15803D),
  _ => AppTheme.textSecondary,
};

/// Tiket bantuan buatan leader ini (Tahap 4, F12). Tiket ditujukan ke semua
/// SPV atau semua finance; siapa pun di antara mereka boleh menanggapi.
class HelpTicketListPage extends ConsumerWidget {
  const HelpTicketListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myHelpTicketsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Bantuan'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<HelpTicket>(
            context,
            MaterialPageRoute(builder: (_) => const HelpTicketFormPage()),
          );
          if (created == null || !context.mounted) return;
          ref.invalidate(myHelpTicketsProvider);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HelpTicketDetailPage(ticketId: created.id)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Buat tiket'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myHelpTicketsProvider),
        child: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(
            icon: Icons.error_outline,
            message: '$e',
            onRetry: () => ref.invalidate(myHelpTicketsProvider),
          ),
          data: (rows) => ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 96 + bottomInset),
            children: [
              const SdmNote(
                icon: Icons.info_outline,
                text: 'Minta bantuan SPV (alat rusak, stok, karyawan) atau finance (dana). '
                    'Kamu mendapat notifikasi saat tiket disetujui, ditolak, atau ditandai selesai.',
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const SdmEmpty(icon: Icons.support_agent, message: 'Belum ada tiket.')
              else
                for (final t in rows) ...[
                  _TicketCard(t: t),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final HelpTicket t;
  const _TicketCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final detail = [
      'ke ${helpTargetLabels[t.target] ?? t.target}',
      if (t.createdAt != null) _day.format(t.createdAt!.toLocal()),
      if (t.dueAt != null) 'tenggat ${_due.format(t.dueAt!.toLocal())}',
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HelpTicketDetailPage(ticketId: t.id)),
      ),
      child: SdmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.categoryName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                ),
                SdmPill(helpStatusLabels[t.status] ?? t.status, color: helpStatusColor(t.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(detail, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ),
                if (t.overdue)
                  const SdmPill('Lewat tenggat', color: AppTheme.danger)
                else if (t.late == true)
                  const SdmPill('Terlambat', color: AppTheme.danger),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
