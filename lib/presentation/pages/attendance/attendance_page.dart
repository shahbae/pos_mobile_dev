import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/core/utils/location_helper.dart';
import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/data/models/leave_out_model.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/data/repositories/attendance_repository.dart';
import 'package:pos_mobile/data/repositories/shift_repository.dart';
import 'package:pos_mobile/presentation/pages/payroll/payroll_widgets.dart';
import 'package:pos_mobile/presentation/providers/attendance_gate_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _clock = DateFormat('HH.mm', 'id_ID');

/// Halaman absensi karyawan: check-in / check-out dengan selfie + GPS.
///
/// Tahap 1 SDM: isinya mengikuti jadwal hari ini (`GET /attendance/me/day`).
/// Ada shift yang jendelanya terbuka → absen masuk menempel ke shift itu, tanpa
/// memilih shift. Tanpa jadwal → memilih shift seperti dulu. Dobel shift →
/// absen masuk/pulang per shift.
///
/// [isRoot] true bila halaman ini dipakai sebagai layar utama (tanpa tombol
/// kembali + ada aksi logout) — dipakai role absensi-saja seperti `finance`.
/// Role lain membukanya dari menu Pengaturan — atau mendarat di sini karena
/// aplikasi terkunci sebelum absen masuk ([gateNotice], revisi 17 Okt 2026).
class AttendancePage extends ConsumerStatefulWidget {
  final bool isRoot;

  /// Penjelasan kenapa hanya halaman ini yang terbuka. Null = dibuka biasa.
  final String? gateNotice;
  const AttendancePage({super.key, this.isRoot = false, this.gateNotice});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  bool _submitting = false;
  String _progress = '';
  int? _selectedBranchId;
  String _selectedShift = AttendanceShift.shift1;

  /// Menilai ulang status shift tiap 30 detik, supaya tombol absen masuk
  /// menyala sendiri saat jendelanya dibuka.
  Timer? _ticker;

  /// Cabang token dihitung ulang paling banyak sekali otomatis per halaman.
  bool _sessionRetried = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayAsync = ref.watch(myDayProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Absensi'),
        centerTitle: true,
        automaticallyImplyLeading: !widget.isRoot,
        actions: widget.isRoot
            ? [
                if (canUsePayroll(ref.watch(authProvider).held)) const PayrollMenuButton(),
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout),
                  onPressed: _submitting
                      ? null
                      : () => ref.read(authProvider.notifier).logout(),
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              refreshMyDay(ref);
              try {
                await ref.read(myDayProvider.future);
              } catch (_) {}
            },
            child: dayAsync.when(
              loading: () => const _Loading(),
              error: (e, _) => _ErrorView(
                message: '$e',
                onRetry: () => refreshMyDay(ref),
              ),
              data: (day) {
                _maybeRecoverBranch(day);
                return _Content(
                  day: day,
                  gateNotice: widget.gateNotice,
                  selectedBranchId: _selectedBranchId,
                  onBranchChanged: (id) => setState(() => _selectedBranchId = id),
                  selectedShift: _selectedShift,
                  onShiftChanged: (s) => setState(() => _selectedShift = s),
                  onCheckIn: _submitting ? null : () => _checkIn(day),
                  onCheckOut: _submitting ? null : () => _checkOut(day),
                  onReloadSession: _submitting ? null : () => _reloadSession(),
                  onStartLeaveOut: _submitting ? null : (colleagues) => _startLeaveOut(colleagues),
                  onEndLeaveOut: _submitting ? null : (id) => _endLeaveOut(id),
                );
              },
            ),
          ),
          if (_submitting) _OverlayProgress(label: _progress),
        ],
      ),
    );
  }

  /// Kasir yang tadinya tanpa jadwal: begitu jadwal hari ini terisi, cabangnya
  /// baru muncul di token sesudah refresh. Dicoba sekali otomatis.
  void _maybeRecoverBranch(MyDay day) {
    final auth = ref.read(authProvider);
    if (_sessionRetried || auth.branchId != null || isOwnerLevel(auth.held)) return;
    final scheduledAtBranch = day.shifts.any((s) =>
        s.location.isBranch &&
        const {MyDayShiftStatus.upcoming, MyDayShiftStatus.open, MyDayShiftStatus.checkedIn}
            .contains(s.status));
    if (!scheduledAtBranch) return;
    _sessionRetried = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloadSession(silent: true);
    });
  }

  Future<void> _reloadSession({bool silent = false}) async {
    setState(() {
      _submitting = true;
      _progress = 'Memuat ulang jadwal…';
    });
    try {
      final changed = await ref.read(authProvider.notifier).refreshSession();
      if (!mounted) return;
      if (changed) {
        // Cabang di token baru: semua data cabang dimuat ulang, termasuk hari
        // saya dan daftar cabang yang boleh dibuka.
        ref.invalidate(branchListProvider);
        ref.read(branchScopeProvider.notifier).state++;
      } else {
        refreshMyDay(ref);
        if (!silent) {
          _snack('Belum bisa memuat ulang. Keluar lalu masuk lagi supaya jadwal '
              'hari ini terbaca.', error: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = '';
        });
      }
    }
  }

  Future<void> _checkIn(MyDay day) async {
    final auth = ref.read(authProvider);
    final canChooseBranch = canChooseAttendanceBranch(auth.role);
    final current = day.currentShift;

    // Untuk role selain owner/supervisor, BE mengabaikan `branch_id` dan
    // memakai cabang dari token — kirim null, tapi pastikan user memang punya
    // cabang supaya tidak kena `403 no branch assigned`.
    //
    // Owner/supervisor wajib mengirim cabang. Kalau absennya menempel ke
    // jadwal di cabang tertentu, server memakai cabang jadwal itu.
    final int? branchId;
    if (canChooseBranch) {
      branchId = current != null && current.location.isBranch
          ? current.location.id
          : _selectedBranchId ?? auth.branchId;
      if (branchId == null) {
        _snack('Pilih cabang terlebih dahulu.', error: true);
        return;
      }
    } else {
      if (auth.branchId == null) {
        _snack(requiresAttendanceGate(auth.held) ? kNoScheduleTodayMsg : kNoBranchAssignedMsg,
            error: true);
        return;
      }
      branchId = null;
    }

    final yakin = await confirmAction(
      context,
      title: 'Absen masuk sekarang?',
      message: current == null
          ? 'Jam masuk dicatat saat ini juga dan hanya bisa diubah oleh owner.'
          : '${current.title}${current.location.name.isEmpty ? '' : ' di ${current.location.name}'}. '
              'Jam masuk dicatat saat ini juga dan hanya bisa diubah oleh owner.',
      confirmLabel: 'Ya, absen masuk',
    );
    if (!yakin || !mounted) return;

    await _run(() async {
      setState(() => _progress = 'Mengambil foto…');
      final photo = await _takeSelfie();
      if (photo == null) return null;

      setState(() => _progress = 'Mendeteksi lokasi…');
      final pos = await LocationHelper.getCurrentPosition();

      setState(() => _progress = 'Menyimpan absen masuk…');
      return ref.read(attendanceRepositoryProvider).checkIn(
            photoPath: photo.path,
            branchId: branchId,
            // Shift hanya untuk absen tanpa jadwal.
            shift: current == null ? _selectedShift : null,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
    }, successMsg: 'Absen masuk berhasil.', afterSuccess: (att) async {
      // Dobel shift di dua outlet: absen shift kedua tercatat di outlet
      // jadwalnya, dan cabang di token ikut pindah ke sana.
      final target = att.branchId;
      if (canChooseBranch || target == null || target == ref.read(authProvider).branchId) return;
      try {
        await ref.read(branchSwitchProvider.notifier).switchBranch(target);
      } catch (e) {
        if (mounted) _snack('Absen tercatat, tapi gagal pindah cabang: $e', error: true);
      }
    });
  }

  /// Shift yang dibuka orang ini dan masih berjalan, atau null. Gagal
  /// memeriksa → null: server tetap menolak absen pulang bila shiftnya buka.
  Future<bool> _ownShiftStillOpen(AttendanceModel? att) async {
    if (!canOperateShift(ref.read(authProvider).role)) return false;
    try {
      final shift = await ref.read(shiftRepositoryProvider).getCurrent();
      if (shift == null || !shift.isOpen) return false;
      return shift.cashierId == null || att == null || shift.cashierId == att.userId;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkOut(MyDay day) async {
    final att = day.openAttendance;
    // Revisi 17 Okt 2026: sesudah absen pulang aplikasi terkunci, jadi shift
    // yang masih buka tidak akan bisa ditutup lagi. Ditahan di sini, sebelum
    // foto diambil; server menolaknya juga.
    setState(() {
      _submitting = true;
      _progress = 'Memeriksa shift…';
    });
    final shiftOpen = await _ownShiftStillOpen(att);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _progress = '';
    });
    if (shiftOpen) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tutup shift dulu'),
          content: const Text(
              'Shift kasir yang kamu buka masih berjalan. Tutup shift dan serahkan '
              'setoran dulu, baru absen pulang.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti')),
          ],
        ),
      );
      return;
    }

    final gated = requiresAttendanceGate(ref.read(authProvider).held);
    final next = day.hasNextShift;
    final yakin = await confirmAction(
      context,
      title: 'Absen pulang sekarang?',
      message: !gated
          ? 'Jam pulang dicatat saat ini juga dan hanya bisa diubah oleh owner.'
          : next
              ? 'Jam pulang dicatat saat ini juga. Aplikasi terbuka lagi setelah '
                  'kamu absen masuk shift berikutnya.'
              : 'Jam pulang dicatat saat ini juga. Sesudah itu aplikasi terkunci '
                  'sampai besok.',
      confirmLabel: 'Ya, absen pulang',
    );
    if (!yakin || !mounted) return;

    await _run(() async {
      setState(() => _progress = 'Mengambil foto…');
      final photo = await _takeSelfie();
      if (photo == null) return null;

      setState(() => _progress = 'Mendeteksi lokasi…');
      final pos = await LocationHelper.getCurrentPosition();

      setState(() => _progress = 'Menyimpan absen pulang…');
      return ref.read(attendanceRepositoryProvider).checkOut(
            photoPath: photo.path,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
    }, successMsg: 'Absen pulang berhasil.', afterSuccess: (_) async {
      // Dibuka dari menu: kembali ke layar paling bawah, yang kini sudah
      // berganti jadi layar terkunci (atau Absensi, bila masih ada shift).
      if (gated && !widget.isRoot && mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
  }

  Future<void> _startLeaveOut(List<OnDutyModel> colleagues) async {
    final input = await showModalBottomSheet<_LeaveOutInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LeaveOutSheet(colleagues: colleagues),
    );
    if (input == null || !mounted) return;
    setState(() {
      _submitting = true;
      _progress = 'Mencatat izin keluar…';
    });
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .startLeaveOut(reason: input.reason, handoverUserId: input.handoverUserId);
      if (!mounted) return;
      ref.invalidate(onDutyProvider);
      _snack('Izin keluar tercatat. Tekan "Saya sudah kembali" begitu kembali.');
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = '';
        });
      }
    }
  }

  Future<void> _endLeaveOut(int id) async {
    setState(() {
      _submitting = true;
      _progress = 'Mencatat kembali…';
    });
    try {
      await ref.read(attendanceRepositoryProvider).endLeaveOut(id);
      if (!mounted) return;
      ref.invalidate(onDutyProvider);
      _snack('Selamat bekerja lagi. Jam kembali tercatat.');
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = '';
        });
      }
    }
  }

  /// Menjalankan aksi absensi dengan overlay & error handling seragam.
  /// [action] mengembalikan absen yang tersimpan, atau null bila dibatalkan.
  Future<void> _run(Future<AttendanceModel?> Function() action,
      {required String successMsg,
      Future<void> Function(AttendanceModel att)? afterSuccess}) async {
    setState(() => _submitting = true);
    try {
      final att = await action();
      if (!mounted) return;
      if (att != null) {
        await afterSuccess?.call(att);
        if (!mounted) return;
        // Penguncian aplikasi dan tugas hari ini ikut membaca ulang.
        refreshMyDay(ref);
        ref.invalidate(attendanceTodayProvider);
        ref.invalidate(attendanceGateProvider);
        _snack(successMsg);
      }
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = '';
        });
      }
    }
  }

  Future<XFile?> _takeSelfie() {
    return ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70, // jaga ukuran tetap di bawah 5 MB
      maxWidth: 1280,
    );
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

class _Content extends ConsumerWidget {
  final MyDay day;
  final String? gateNotice;
  final int? selectedBranchId;
  final ValueChanged<int?> onBranchChanged;
  final String selectedShift;
  final ValueChanged<String> onShiftChanged;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCheckOut;
  final VoidCallback? onReloadSession;
  final ValueChanged<List<OnDutyModel>>? onStartLeaveOut;
  final ValueChanged<int>? onEndLeaveOut;

  const _Content({
    required this.day,
    this.gateNotice,
    required this.selectedBranchId,
    required this.onBranchChanged,
    required this.selectedShift,
    required this.onShiftChanged,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onReloadSession,
    required this.onStartLeaveOut,
    required this.onEndLeaveOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final today = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    final auth = ref.watch(authProvider);
    final canChooseBranch = canChooseAttendanceBranch(auth.role);
    final open = day.openAttendance;
    final current = open == null ? day.currentShift : null;
    final next = open == null && current == null ? day.nextShift : null;
    final serverNow = day.serverNow;
    // Cabang wajib ada untuk role yang cabangnya diambil dari token.
    final noBranch = !canChooseBranch && auth.branchId == null && open == null;

    final children = <Widget>[
      _DateHeader(dateLabel: today),
      const SizedBox(height: 16),
      if (gateNotice != null) ...[
        _InfoBanner(icon: Icons.lock_outline, text: gateNotice!, warning: true),
        const SizedBox(height: 12),
      ],
      if (noBranch) ...[
        _InfoBanner(
          icon: Icons.event_busy_outlined,
          text: requiresAttendanceGate(auth.held) ? kNoScheduleTodayMsg : kNoBranchAssignedMsg,
          warning: true,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onReloadSession,
          icon: const Icon(Icons.refresh),
          label: const Text('Muat ulang'),
        ),
        const SizedBox(height: 16),
      ],
      if (day.shifts.isNotEmpty) ...[
        const _SectionLabel('Jadwal hari ini'),
        const SizedBox(height: 8),
        for (final s in day.shifts) ...[
          _ShiftTile(shift: s, status: s.statusAt(serverNow)),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
      ],
      for (final a in day.attendances) ...[
        _AttendanceCard(att: a),
        const SizedBox(height: 12),
      ],
    ];

    if (open != null) {
      children.addAll([
        _InfoBanner(
          icon: Icons.timer_outlined,
          text: 'Kamu sedang bekerja (${open.shiftLabel}). Jangan lupa absen pulang '
              'saat selesai bekerja.',
        ),
        const SizedBox(height: 16),
        if (open.branchId != null && canLeaveOut(auth.held)) ...[
          _LeaveOutBox(
            attendance: open,
            branchId: isOwnerLevel(auth.held) ? open.branchId : null,
            onStart: onStartLeaveOut,
            onEnd: onEndLeaveOut,
          ),
          const SizedBox(height: 16),
        ],
        _ActionButton(label: 'Absen Pulang', icon: Icons.logout, onPressed: onCheckOut),
      ]);
    } else if (current != null) {
      children.addAll([
        _InfoBanner(
          icon: Icons.fingerprint,
          text: 'Absen masuk ${current.shiftCode.name}'
              '${current.location.name.isEmpty ? '' : ' di ${current.location.name}'}. '
              'Shift dan tugas diambil dari jadwal.',
        ),
        const SizedBox(height: 16),
        if (canChooseBranch && current.location.isRoving) ...[
          _BranchPicker(selected: selectedBranchId ?? auth.branchId, onChanged: onBranchChanged),
          const SizedBox(height: 16),
        ],
        _ActionButton(
          label: 'Absen Masuk',
          icon: Icons.login,
          onPressed: noBranch ? null : onCheckIn,
        ),
      ]);
    } else if (next != null) {
      children.addAll([
        _InfoBanner(
          icon: Icons.schedule,
          text: next.opensAt == null
              ? 'Absen masuk ${next.shiftCode.name} belum dibuka.'
              : 'Absen masuk ${next.shiftCode.name} dibuka jam '
                  '${_clock.format(next.opensAt!.toLocal())}.',
        ),
        const SizedBox(height: 16),
        const _ActionButton(label: 'Absen Masuk', icon: Icons.login, onPressed: null),
      ]);
    } else if (!day.hasAttendance) {
      // Tanpa jadwal hari ini (atau shiftnya sudah lewat): memilih shift
      // seperti dulu. Di cabang yang wajib jadwal, server yang menolaknya.
      final missed = day.shifts.isNotEmpty;
      children.addAll([
        if (!noBranch)
          _InfoBanner(
            icon: missed ? Icons.warning_amber_rounded : Icons.fingerprint,
            text: missed
                ? 'Shift di jadwal hari ini sudah lewat tanpa absen. Hubungi leader '
                    'bila jadwalnya keliru.'
                : 'Anda belum absen hari ini. Pilih shift, lalu tekan Absen Masuk.',
            warning: missed,
          ),
        const SizedBox(height: 16),
        if (canChooseBranch) ...[
          _BranchPicker(selected: selectedBranchId ?? auth.branchId, onChanged: onBranchChanged),
          const SizedBox(height: 16),
        ],
        _ShiftPicker(selected: selectedShift, onChanged: onShiftChanged),
        const SizedBox(height: 16),
        _ActionButton(
          label: 'Absen Masuk',
          icon: Icons.login,
          onPressed: noBranch ? null : onCheckIn,
        ),
      ]);
    } else {
      children.add(const _InfoBanner(
        icon: Icons.check_circle_outline,
        text: 'Absensi hari ini sudah lengkap. Sampai jumpa besok!',
        success: true,
      ));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
      children: children,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary));
}

/// Satu shift di jadwal hari ini beserta statusnya.
class _ShiftTile extends StatelessWidget {
  final MyDayShift shift;
  final MyDayShiftStatus status;
  const _ShiftTile({required this.shift, required this.status});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      MyDayShiftStatus.upcoming => (
          shift.opensAt == null
              ? 'Belum dibuka'
              : 'Dibuka ${_clock.format(shift.opensAt!.toLocal())}',
          AppTheme.textSecondary
        ),
      MyDayShiftStatus.open => ('Bisa absen masuk', AppTheme.brandBlue),
      MyDayShiftStatus.checkedIn => ('Sedang bekerja', AppTheme.brandGreenDark),
      MyDayShiftStatus.done => ('Selesai', AppTheme.brandGreenDark),
      MyDayShiftStatus.missed => ('Terlewat', AppTheme.danger),
      MyDayShiftStatus.absent => ('Alpa', AppTheme.danger),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_note_outlined, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                if (shift.location.name.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(shift.location.name,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(text: label, color: color),
        ],
      ),
    );
  }
}

/// Satu absen: jam masuk & pulang, plus tanda telat, lewat batas, dan lembur.
class _AttendanceCard extends StatelessWidget {
  final AttendanceModel att;
  const _AttendanceCard({required this.att});

  @override
  Widget build(BuildContext context) {
    String time(DateTime? t) => t == null ? '-' : _clock.format(t.toLocal());
    final late = att.lateMinutes ?? 0;
    final ot = att.overtime;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhotoThumb(url: att.checkInPhotoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(att.shiftLabel,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: _Stamp(label: 'Masuk', value: time(att.checkInAt))),
                    Expanded(child: _Stamp(label: 'Pulang', value: time(att.checkOutAt))),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(status: att.checkInStatus),
                    if (att.schedule?.duty != null)
                      _Pill(
                          text: ScheduleDuty.label(att.schedule!.duty),
                          color: AppTheme.brandGreenDark),
                    if (late > 0) _Pill(text: 'Telat $late menit', color: const Color(0xFFD97706)),
                    if (att.checkoutPastLimit)
                      const _Pill(text: 'Pulang lewat batas', color: Color(0xFFD97706)),
                    if (ot != null)
                      _Pill(
                        text: ot.minutes == null ? 'Lembur' : 'Lembur ${ot.minutes} menit',
                        color: AppTheme.brandBlue,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  final String label;
  final String value;
  const _Stamp({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
      ],
    );
  }
}

/// Izin keluar sebentar dari outlet selama bertugas. Status "sedang keluar"
/// dibaca dari daftar yang sedang bertugas di outlet ini.
class _LeaveOutBox extends ConsumerWidget {
  final AttendanceModel attendance;

  /// Cabang yang dibaca; null = cabang token.
  final int? branchId;
  final ValueChanged<List<OnDutyModel>>? onStart;
  final ValueChanged<int>? onEnd;

  const _LeaveOutBox({
    required this.attendance,
    required this.branchId,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duty = ref.watch(onDutyProvider(branchId));
    return duty.when(
      loading: () => const LinearProgressIndicator(),
      // Gagal membaca: tombolnya tetap ada; server yang menolak bila perlu.
      error: (_, _) => OutlinedButton.icon(
        onPressed: onStart == null ? null : () => onStart!(const []),
        icon: const Icon(Icons.directions_walk),
        label: const Text('Izin keluar sebentar'),
      ),
      data: (rows) {
        OnDutyModel? me;
        for (final r in rows) {
          if (r.attendanceId == attendance.id) me = r;
        }
        final leaveId = me?.leaveOutId;
        if (leaveId != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _InfoBanner(
                icon: Icons.directions_walk,
                text: 'Kamu sedang izin keluar. Tekan tombol di bawah begitu kembali '
                    'ke outlet.',
                warning: true,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onEnd == null ? null : () => onEnd!(leaveId),
                icon: const Icon(Icons.keyboard_return),
                label: const Text('Saya sudah kembali'),
              ),
            ],
          );
        }
        final colleagues = [
          for (final r in rows)
            if (r.attendanceId != attendance.id && r.userId != attendance.userId) r,
        ];
        return OutlinedButton.icon(
          onPressed: onStart == null ? null : () => onStart!(colleagues),
          icon: const Icon(Icons.directions_walk),
          label: const Text('Izin keluar sebentar'),
        );
      },
    );
  }
}

class _LeaveOutInput {
  final String reason;
  final int? handoverUserId;
  const _LeaveOutInput(this.reason, this.handoverUserId);
}

class _LeaveOutSheet extends StatefulWidget {
  final List<OnDutyModel> colleagues;
  const _LeaveOutSheet({required this.colleagues});

  @override
  State<_LeaveOutSheet> createState() => _LeaveOutSheetState();
}

class _LeaveOutSheetState extends State<_LeaveOutSheet> {
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
                ? () => Navigator.pop(context, _LeaveOutInput(_reason.text.trim(), _handover))
                : null,
            child: const Text('Catat keluar'),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String dateLabel;
  const _DateHeader({required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hari ini',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(dateLabel,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchPicker extends ConsumerWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;
  const _BranchPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cabang',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        branchesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Gagal memuat cabang: $e',
              style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
          data: (branches) {
            final ids = branches.map((b) => b.id).toSet();
            final value = ids.contains(selected) ? selected : null;
            return DropdownButtonFormField<int>(
              initialValue: value,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.store_outlined),
              ),
              hint: const Text('Pilih cabang'),
              items: branches
                  .map((BranchModel b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: onChanged,
            );
          },
        ),
      ],
    );
  }
}

class _ShiftPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ShiftPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Shift',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AttendanceShift.values.map((s) {
            final isSel = s == selected;
            return ChoiceChip(
              label: Text(AttendanceShift.label(s)),
              selected: isSel,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: isSel ? Colors.white : AppTheme.textPrimary,
              ),
              selectedColor: accent,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSel ? accent : AppTheme.borderLight,
              ),
              onSelected: (_) => onChanged(s),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String? url;
  const _PhotoThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        height: 64,
        child: url == null || url!.isEmpty
            ? Container(
                color: AppTheme.bgLight,
                child: const Icon(Icons.person, color: AppTheme.textSecondary),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.bgLight,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppTheme.textSecondary),
                ),
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String? status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (status) {
      case 'valid':
        label = 'Lokasi sesuai';
        color = AppTheme.brandBlue;
        break;
      case 'outside_radius':
        label = 'Di luar area cabang';
        color = const Color(0xFFD97706);
        break;
      case 'no_branch_geo':
        label = 'Lokasi cabang belum diatur';
        color = AppTheme.textSecondary;
        break;
      default:
        label = status ?? '-';
        color = AppTheme.textSecondary;
    }
    return _Pill(text: label, color: color);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool success;
  final bool warning;
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.success = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? const Color(0xFFD97706)
        : success
            ? AppTheme.brandBlue
            : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: success ? AppTheme.brandGreenDark : AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _ActionButton(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => ListView(
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
        const SizedBox(height: 12),
        Text('Gagal memuat status absensi:\n$message',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ),
      ],
    );
  }
}

class _OverlayProgress extends StatelessWidget {
  final String label;
  const _OverlayProgress({required this.label});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                Text(label.isEmpty ? 'Memproses…' : label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
