import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/leave_out_model.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/widgets/setting_menu_card.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Izin keluar sebentar dari outlet selama bertugas, sebagai kartu di tab
/// Pengaturan tepat di atas Logout (revisi owner 24 Nov 2026; tadinya tombol di
/// halaman Absensi). Status "sedang keluar" dibaca dari daftar yang sedang
/// bertugas di outlet ini. Bagi yang berhak ([canLeaveOut]) kartunya selalu
/// ada, tetapi redup dan tak bisa diketuk selama belum absen masuk.
class LeaveOutMenuCard extends ConsumerStatefulWidget {
  const LeaveOutMenuCard({super.key});

  @override
  ConsumerState<LeaveOutMenuCard> createState() => _LeaveOutMenuCardState();
}

class _LeaveOutMenuCardState extends ConsumerState<LeaveOutMenuCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final open = ref.watch(myDayProvider).valueOrNull?.openAttendance;
    const icon = Icons.directions_walk;
    final accent = Theme.of(context).colorScheme.primary;

    // Belum absen masuk (atau absen tanpa cabang): tak ada outlet untuk ditinggal.
    if (open == null || open.branchId == null) {
      return SettingMenuCard(
        title: 'Izin keluar sebentar',
        subtitle: 'Hanya saat sedang bertugas (sudah absen masuk)',
        icon: icon,
        color: accent,
      );
    }

    // Owner/SPV membaca cabang absennya; role lain cabang token.
    final branchId = isOwnerLevel(auth.held) ? open.branchId : null;
    final duty = ref.watch(onDutyProvider(branchId));
    return duty.when(
      loading: () => SettingMenuCard(
        title: 'Izin keluar sebentar',
        subtitle: 'Memuat status…',
        icon: icon,
        color: accent,
      ),
      // Gagal membaca: tombolnya tetap ada; server yang menolak bila perlu.
      error: (_, _) => SettingMenuCard(
        title: 'Izin keluar sebentar',
        subtitle: 'Catat keluar dari outlet, bisa serah tugas ke rekan',
        icon: icon,
        color: accent,
        onTap: _busy ? null : () => _start(const []),
      ),
      data: (rows) {
        OnDutyModel? me;
        for (final r in rows) {
          if (r.attendanceId == open.id) me = r;
        }
        final leaveId = me?.leaveOutId;
        if (leaveId != null) {
          return SettingMenuCard(
            title: 'Saya sudah kembali',
            subtitle: 'Kamu sedang izin keluar. Ketuk begitu kembali ke outlet.',
            icon: Icons.keyboard_return,
            color: const Color(0xFFEA580C),
            onTap: _busy ? null : () => _end(leaveId),
          );
        }
        final colleagues = [
          for (final r in rows)
            if (r.attendanceId != open.id && r.userId != open.userId) r,
        ];
        return SettingMenuCard(
          title: 'Izin keluar sebentar',
          subtitle: 'Catat keluar dari outlet, bisa serah tugas ke rekan',
          icon: icon,
          color: accent,
          onTap: _busy ? null : () => _start(colleagues),
        );
      },
    );
  }

  Future<void> _start(List<OnDutyModel> colleagues) async {
    final input = await showModalBottomSheet<LeaveOutInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LeaveOutSheet(colleagues: colleagues),
    );
    if (input == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .startLeaveOut(reason: input.reason, handoverUserId: input.handoverUserId);
      if (!mounted) return;
      ref.invalidate(onDutyProvider);
      _snack('Izin keluar tercatat. Ketuk "Saya sudah kembali" begitu kembali.');
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end(int id) async {
    setState(() => _busy = true);
    try {
      await ref.read(attendanceRepositoryProvider).endLeaveOut(id);
      if (!mounted) return;
      ref.invalidate(onDutyProvider);
      _snack('Selamat bekerja lagi. Jam kembali tercatat.');
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
      ),
    );
  }
}

class LeaveOutInput {
  final String reason;
  final int? handoverUserId;
  const LeaveOutInput(this.reason, this.handoverUserId);
}

class LeaveOutSheet extends StatefulWidget {
  final List<OnDutyModel> colleagues;
  const LeaveOutSheet({super.key, required this.colleagues});

  @override
  State<LeaveOutSheet> createState() => LeaveOutSheetState();
}

class LeaveOutSheetState extends State<LeaveOutSheet> {
  final _reason = TextEditingController();
  int? _handover;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ready = _reason.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Izin keluar sebentar',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Jam keluar dicatat sekarang. Leader bisa melihat catatannya.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            autofocus: true,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alasan',
              hintText: 'mis. beli es batu',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _handover,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Serah tugas ke (boleh kosong)'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Tanpa serah tugas')),
              for (final c in widget.colleagues)
                DropdownMenuItem<int?>(value: c.userId, child: Text(c.userName)),
            ],
            onChanged: (v) => setState(() => _handover = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: ready
                ? () => Navigator.pop(context, LeaveOutInput(_reason.text.trim(), _handover))
                : null,
            child: const Text('Catat keluar'),
          ),
        ],
      ),
    );
  }
}
