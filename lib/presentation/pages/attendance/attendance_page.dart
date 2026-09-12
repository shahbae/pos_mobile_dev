import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/core/utils/location_helper.dart';
import 'package:pos_mobile/data/models/attendance_model.dart';
import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/data/repositories/attendance_repository.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Halaman absensi karyawan: check-in / check-out dengan selfie + GPS.
/// Status hari ini menentukan tombol mana yang tampil.
///
/// [isRoot] true bila halaman ini dipakai sebagai layar utama (tanpa tombol
/// kembali + ada aksi logout) — dipakai role absensi-saja seperti `finance`.
/// Role lain membukanya dari menu Pengaturan.
class AttendancePage extends ConsumerStatefulWidget {
  final bool isRoot;
  const AttendancePage({super.key, this.isRoot = false});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  bool _submitting = false;
  String _progress = '';
  int? _selectedBranchId;
  String _selectedShift = AttendanceShift.shift1;

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(attendanceTodayProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Absensi'),
        centerTitle: true,
        automaticallyImplyLeading: !widget.isRoot,
        actions: widget.isRoot
            ? [
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
            onRefresh: () async => ref.invalidate(attendanceTodayProvider),
            child: todayAsync.when(
              loading: () => const _Loading(),
              error: (e, _) => _ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(attendanceTodayProvider),
              ),
              data: (att) => _Content(
                att: att,
                selectedBranchId: _selectedBranchId,
                onBranchChanged: (id) => setState(() => _selectedBranchId = id),
                selectedShift: _selectedShift,
                onShiftChanged: (s) => setState(() => _selectedShift = s),
                onCheckIn: _submitting ? null : () => _checkIn(att),
                onCheckOut: _submitting ? null : () => _checkOut(),
              ),
            ),
          ),
          if (_submitting) _OverlayProgress(label: _progress),
        ],
      ),
    );
  }

  Future<void> _checkIn(AttendanceModel? att) async {
    final auth = ref.read(authProvider);
    final canChooseBranch = canChooseAttendanceBranch(auth.role);

    // Untuk role selain owner/supervisor, BE mengabaikan `branch_id` dan
    // memakai cabang dari token — kirim null, tapi pastikan user memang punya
    // cabang supaya tidak kena `403 no branch assigned`.
    final int? branchId;
    if (canChooseBranch) {
      branchId = _selectedBranchId ?? auth.branchId;
      if (branchId == null) {
        _snack('Pilih cabang terlebih dahulu.', error: true);
        return;
      }
    } else {
      if (auth.branchId == null) {
        _snack(kNoBranchAssignedMsg, error: true);
        return;
      }
      branchId = null;
    }

    final yakin = await confirmAction(
      context,
      title: 'Absen masuk sekarang?',
      message: 'Jam masuk dicatat saat ini juga dan hanya bisa diubah oleh owner.',
      confirmLabel: 'Ya, absen masuk',
    );
    if (!yakin || !mounted) return;

    await _run(() async {
      setState(() => _progress = 'Mengambil foto…');
      final photo = await _takeSelfie();
      if (photo == null) return false;

      setState(() => _progress = 'Mendeteksi lokasi…');
      final pos = await LocationHelper.getCurrentPosition();

      setState(() => _progress = 'Menyimpan absen masuk…');
      await ref.read(attendanceRepositoryProvider).checkIn(
            photoPath: photo.path,
            branchId: branchId,
            shift: _selectedShift,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      return true;
    }, successMsg: 'Absen masuk berhasil.');
  }

  Future<void> _checkOut() async {
    final yakin = await confirmAction(
      context,
      title: 'Absen pulang sekarang?',
      message: 'Jam pulang dicatat saat ini juga dan hanya bisa diubah oleh owner.',
      confirmLabel: 'Ya, absen pulang',
    );
    if (!yakin || !mounted) return;

    await _run(() async {
      setState(() => _progress = 'Mengambil foto…');
      final photo = await _takeSelfie();
      if (photo == null) return false;

      setState(() => _progress = 'Mendeteksi lokasi…');
      final pos = await LocationHelper.getCurrentPosition();

      setState(() => _progress = 'Menyimpan absen pulang…');
      await ref.read(attendanceRepositoryProvider).checkOut(
            photoPath: photo.path,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      return true;
    }, successMsg: 'Absen pulang berhasil.');
  }

  /// Menjalankan aksi absensi dengan overlay & error handling seragam.
  /// [action] mengembalikan true bila benar-benar terkirim (false = dibatalkan).
  Future<void> _run(Future<bool> Function() action,
      {required String successMsg}) async {
    setState(() => _submitting = true);
    try {
      final done = await action();
      if (!mounted) return;
      if (done) {
        ref.invalidate(attendanceTodayProvider);
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
  final AttendanceModel? att;
  final int? selectedBranchId;
  final ValueChanged<int?> onBranchChanged;
  final String selectedShift;
  final ValueChanged<String> onShiftChanged;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCheckOut;

  const _Content({
    required this.att,
    required this.selectedBranchId,
    required this.onBranchChanged,
    required this.selectedShift,
    required this.onShiftChanged,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final today = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    final auth = ref.watch(authProvider);
    final canChooseBranch = canChooseAttendanceBranch(auth.role);
    // Cabang wajib ada untuk role yang cabangnya diambil dari token.
    final noBranch = !canChooseBranch && auth.branchId == null;

    final children = <Widget>[
      _DateHeader(dateLabel: today),
      const SizedBox(height: 16),
    ];

    if (att == null) {
      // Belum check-in hari ini.
      children.addAll([
        if (noBranch)
          const _InfoBanner(
            icon: Icons.store_mall_directory_outlined,
            text: kNoBranchAssignedMsg,
            warning: true,
          )
        else
          const _InfoBanner(
            icon: Icons.fingerprint,
            text: 'Anda belum absen hari ini. Tekan tombol di bawah untuk absen masuk.',
          ),
        const SizedBox(height: 16),
        if (canChooseBranch) ...[
          _BranchPicker(
            selected: selectedBranchId ?? auth.branchId,
            onChanged: onBranchChanged,
          ),
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
      children.add(_CheckCard(
        title: 'Absen Masuk',
        time: att!.checkInAt,
        status: att!.checkInStatus,
        shift: att!.shift,
        photoUrl: att!.checkInPhotoUrl,
      ));
      if (att!.hasCheckedOut) {
        children.addAll([
          const SizedBox(height: 12),
          _CheckCard(
            title: 'Absen Pulang',
            time: att!.checkOutAt,
            status: att!.checkOutStatus,
            photoUrl: att!.checkOutPhotoUrl,
          ),
          const SizedBox(height: 16),
          const _InfoBanner(
            icon: Icons.check_circle_outline,
            text: 'Absensi hari ini sudah lengkap. Sampai jumpa besok!',
            success: true,
          ),
        ]);
      } else {
        children.addAll([
          const SizedBox(height: 16),
          const _InfoBanner(
            icon: Icons.timer_outlined,
            text: 'Anda sudah absen masuk. Jangan lupa absen pulang saat selesai bekerja.',
          ),
          const SizedBox(height: 16),
          _ActionButton(
            label: 'Absen Pulang',
            icon: Icons.logout,
            onPressed: onCheckOut,
          ),
        ]);
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
      children: children,
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

class _CheckCard extends StatelessWidget {
  final String title;
  final DateTime? time;
  final String? status;
  final String? shift;
  final String? photoUrl;

  const _CheckCard({
    required this.title,
    required this.time,
    required this.status,
    this.shift,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        time != null ? DateFormat('HH:mm', 'id_ID').format(time!.toLocal()) : '-';
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
          _PhotoThumb(url: photoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(timeLabel,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(status: status),
                    if (shift != null && shift!.isNotEmpty)
                      _Pill(
                        text: AttendanceShift.label(shift),
                        color: AppTheme.brandGreenDark,
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
