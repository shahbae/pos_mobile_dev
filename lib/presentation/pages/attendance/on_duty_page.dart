import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/leave_out_model.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _clock = DateFormat('HH.mm', 'id_ID');

/// Yang sedang bertugas di outlet ini (Tahap 1 SDM), untuk leader, SPV, dan
/// owner: siapa yang sudah absen masuk, telat berapa, siapa yang sedang izin
/// keluar — dan tempat menandai lembur.
class OnDutyPage extends ConsumerStatefulWidget {
  const OnDutyPage({super.key});

  @override
  ConsumerState<OnDutyPage> createState() => _OnDutyPageState();
}

class _OnDutyPageState extends ConsumerState<OnDutyPage> {
  bool _busy = false;

  /// Owner/SPV membaca cabang aktif di token; yang lain dikunci server ke
  /// cabang tokennya, jadi tidak perlu dikirim.
  int? get _branchId {
    final auth = ref.read(authProvider);
    return isOwnerLevel(auth.held) ? auth.branchId : null;
  }

  Future<void> _toggleOvertime(OnDutyModel row) async {
    final mark = !row.overtime;
    final yakin = await confirmAction(
      context,
      title: mark ? 'Tandai ${row.userName} lembur?' : 'Cabut lembur ${row.userName}?',
      message: mark
          ? 'Lama lembur dihitung dari jam selesai shift sampai ia absen pulang.'
          : 'Kalau ia pulang lewat batas, absennya akan ditandai lewat batas lagi.',
      confirmLabel: mark ? 'Ya, tandai lembur' : 'Ya, cabut',
      danger: !mark,
    );
    if (!yakin || !mounted) return;
    setState(() => _busy = true);
    final repo = ref.read(attendanceRepositoryProvider);
    try {
      if (mark) {
        await repo.markOvertime(row.attendanceId);
      } else {
        await repo.unmarkOvertime(row.attendanceId);
      }
      if (!mounted) return;
      ref.invalidate(onDutyProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mark ? '${row.userName} ditandai lembur.' : 'Lembur dicabut.'),
        backgroundColor: AppTheme.brandBlue,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final branchName = ref.watch(currentBranchProvider)?.name;
    final canMark = canMarkOvertime(auth.held);
    final needsBranch = isOwnerLevel(auth.held) && auth.branchId == null;
    final async = needsBranch ? null : ref.watch(onDutyProvider(_branchId));
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Yang Bertugas'), centerTitle: true),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(onDutyProvider),
            child: async == null
                ? const SdmStateView(
                    icon: Icons.store_outlined,
                    message: 'Pilih cabang aktif dulu lewat menu Ganti Cabang.',
                  )
                : async.when(
                    loading: SdmStateView.loading,
                    error: (e, _) => SdmStateView(
                      icon: Icons.error_outline,
                      message: '$e',
                      onRetry: () => ref.invalidate(onDutyProvider),
                    ),
                    data: (rows) => ListView(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
                      children: [
                        if (branchName != null) ...[
                          Text(branchName,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                        ],
                        if (canMark) ...[
                          const SdmNote(
                            icon: Icons.info_outline,
                            text: 'Tandai lembur saat orangnya masih bekerja melewati jam '
                                'shift. Yang sudah pulang ditandai SPV dari web admin.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (rows.isEmpty)
                          const SdmEmpty(
                            icon: Icons.people_outline,
                            message: 'Belum ada yang absen masuk di outlet ini.',
                          ),
                        for (final r in rows) ...[
                          _DutyCard(
                            row: r,
                            onToggleOvertime: canMark && !_busy ? () => _toggleOvertime(r) : null,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _DutyCard extends StatelessWidget {
  final OnDutyModel row;
  final VoidCallback? onToggleOvertime;
  const _DutyCard({required this.row, required this.onToggleOvertime});

  @override
  Widget build(BuildContext context) {
    final late = row.lateMinutes ?? 0;
    final shift = [
      if (row.shiftName.isNotEmpty) AttendanceShift.label(row.shiftName),
      if (row.duty != null) ScheduleDuty.label(row.duty),
    ].join(' · ');
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.userName,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(
            [
              if (shift.isNotEmpty) shift,
              if (row.checkInAt != null) 'masuk ${_clock.format(row.checkInAt!.toLocal())}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (late > 0) SdmPill('Telat $late menit', color: const Color(0xFFD97706)),
              if (row.leaveOutId != null)
                const SdmPill('Sedang izin keluar', color: Color(0xFFD97706)),
              if (row.overtime) const SdmPill('Lembur', color: AppTheme.brandBlue),
            ],
          ),
          if (onToggleOvertime != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: row.overtime
                  ? TextButton(onPressed: onToggleOvertime, child: const Text('Cabut lembur'))
                  : OutlinedButton.icon(
                      onPressed: onToggleOvertime,
                      icon: const Icon(Icons.more_time),
                      label: const Text('Tandai lembur'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
