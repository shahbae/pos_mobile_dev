import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/leave_out_model.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _clock = DateFormat('HH.mm', 'id_ID');
final _dayLabel = DateFormat('EEEE, d MMMM', 'id_ID');

/// Riwayat izin keluar 7 hari terakhir (Tahap 1 SDM). Leader: outlet yang ia
/// pimpin. Owner/SPV: cabang aktif di token.
class LeaveOutListPage extends ConsumerWidget {
  const LeaveOutListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final branchId = isOwnerLevel(auth.held) ? auth.branchId : null;
    final async = ref.watch(leaveOutsProvider(branchId));
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Izin Keluar'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(leaveOutsProvider),
        child: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(
            icon: Icons.error_outline,
            message: '$e',
            onRetry: () => ref.invalidate(leaveOutsProvider),
          ),
          data: (rows) {
            final groups = <String, List<LeaveOutModel>>{};
            for (final r in rows) {
              final out = r.outAt?.toLocal();
              final key = out == null ? '' : DateFormat('yyyy-MM-dd').format(out);
              groups.putIfAbsent(key, () => []).add(r);
            }
            final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
            return ListView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
              children: [
                const SdmNote(
                  icon: Icons.info_outline,
                  text: '7 hari terakhir. Izin keluar dicatat sendiri oleh yang '
                      'bertugas, tanpa persetujuan.',
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  const SdmEmpty(
                    icon: Icons.directions_walk,
                    message: 'Belum ada izin keluar dalam 7 hari terakhir.',
                  ),
                for (final k in keys) ...[
                  Text(
                    DateTime.tryParse(k) == null ? '-' : _dayLabel.format(DateTime.parse(k)),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  for (final r in groups[k]!) ...[
                    // Owner/SPV tanpa cabang aktif melihat semua cabang.
                    _LeaveOutCard(row: r, showBranch: isOwnerLevel(auth.held) && branchId == null),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LeaveOutCard extends StatelessWidget {
  final LeaveOutModel row;
  final bool showBranch;
  const _LeaveOutCard({required this.row, this.showBranch = false});

  @override
  Widget build(BuildContext context) {
    final out = row.outAt == null ? '-' : _clock.format(row.outAt!.toLocal());
    final back = row.backAt == null ? null : _clock.format(row.backAt!.toLocal());
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.userName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ),
              if (row.isOpen)
                const SdmPill('Belum kembali', color: Color(0xFFD97706))
              else if (row.minutes != null)
                SdmPill('${row.minutes} menit'),
            ],
          ),
          const SizedBox(height: 4),
          Text(row.reason, style: const TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
            [
              if (showBranch && row.branchName.isNotEmpty) row.branchName,
              'Keluar $out',
              if (back != null) row.backAuto ? 'ditutup saat absen pulang $back' : 'kembali $back',
              if (row.handoverName.isNotEmpty) 'serah tugas ke ${row.handoverName}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
