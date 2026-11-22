import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/leave_out_model.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _clock = DateFormat('HH.mm', 'id_ID');

/// Yang sedang bertugas di outlet ini (Tahap 1 SDM), untuk leader, SPV, dan
/// owner: siapa yang sudah absen masuk, telat berapa, siapa yang sedang izin
/// keluar. Tanda lembur manual dicabut (revisi owner 21 Nov 2026): lembur kini
/// dijadwalkan di sel jadwal dan diabsen sendiri lewat Absen Lembur.
class OnDutyPage extends ConsumerStatefulWidget {
  const OnDutyPage({super.key});

  @override
  ConsumerState<OnDutyPage> createState() => _OnDutyPageState();
}

class _OnDutyPageState extends ConsumerState<OnDutyPage> {
  /// Owner/SPV membaca cabang aktif di token; yang lain dikunci server ke
  /// cabang tokennya, jadi tidak perlu dikirim.
  int? get _branchId {
    final auth = ref.read(authProvider);
    return isOwnerLevel(auth.held) ? auth.branchId : null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final branchName = ref.watch(currentBranchProvider)?.name;
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
                ? SdmStateView(
                    icon: Icons.store_outlined,
                    message: branchRequiredMessage(auth.held),
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
                        const SdmNote(
                          icon: Icons.info_outline,
                          text: 'Lembur kini dijadwalkan di jadwal (web) dan diabsen sendiri lewat Absen Lembur.',
                        ),
                        const SizedBox(height: 16),
                        if (rows.isEmpty)
                          const SdmEmpty(
                            icon: Icons.people_outline,
                            message: 'Belum ada yang absen masuk di outlet ini.',
                          ),
                        for (final r in rows) ...[
                          _DutyCard(row: r),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DutyCard extends StatelessWidget {
  final OnDutyModel row;
  const _DutyCard({required this.row});

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
        ],
      ),
    );
  }
}
