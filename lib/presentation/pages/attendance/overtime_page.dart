import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/utils/location_helper.dart';
import 'package:pos_mobile/data/models/overtime_model.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _day = DateFormat('EEEE, d MMMM', 'id_ID');
final _clock = DateFormat('HH.mm', 'id_ID');

/// Absen Lembur (revisi owner 21 Nov 2026): lembur yang dijadwalkan leader/SPV
/// di sel jadwal. Masuk ulang wajib di lokasi lembur (GPS dalam radius) dengan
/// selfie, lalu pulang lembur. Jam yang dibayar dibatasi jam jadwalnya.
class OvertimePage extends ConsumerStatefulWidget {
  const OvertimePage({super.key});

  @override
  ConsumerState<OvertimePage> createState() => _OvertimePageState();
}

class _OvertimePageState extends ConsumerState<OvertimePage> {
  bool _busy = false;
  String _progress = '';

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
      duration: Duration(seconds: error ? 6 : 3),
    ));
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = '';
        });
      }
    }
  }

  /// Minta token baru supaya cabang di token dihitung ulang (lembur aktif =
  /// cabang lembur), lalu baca ulang hari saya. Gagal tidak menggagalkan absen.
  Future<void> _reloadBranch() async {
    try {
      await ref.read(authProvider.notifier).refreshSession();
    } catch (_) {}
    refreshMyDay(ref);
  }

  Future<void> _checkIn(ScheduledOvertime ot) async {
    final yakin = await confirmAction(
      context,
      title: 'Masuk ulang lembur?',
      message: 'Lembur ${ot.hoursLabel} di ${ot.location.name}. Ambil selfie di lokasi; '
          'GPS harus dalam radius ${ot.location.name}.',
      confirmLabel: 'Ya, masuk ulang',
    );
    if (!yakin || !mounted) return;
    await _run(() async {
      setState(() => _progress = 'Mengambil foto…');
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (photo == null) return;
      setState(() => _progress = 'Mendeteksi lokasi…');
      final pos = await LocationHelper.getCurrentPosition();
      setState(() => _progress = 'Menyimpan masuk ulang…');
      await ref.read(attendanceRepositoryProvider).overtimeCheckIn(
            id: ot.id,
            photoPath: photo.path,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      ref.invalidate(myOvertimesProvider);
      // Lembur di outlet lain (revisi owner 26 Nov 2026): token baru membawa
      // cabang lembur, jadi app pindah ke outlet itu selama lembur.
      await _reloadBranch();
      _snack('Masuk ulang lembur tercatat. Jangan lupa pulang lembur.');
    });
  }

  Future<void> _checkOut(ScheduledOvertime ot) async {
    final yakin = await confirmAction(
      context,
      title: 'Pulang lembur sekarang?',
      message: 'Ambil selfie dulu. Jam yang dibayar dihitung sampai sekarang, paling lambat '
          '${ot.endTime.replaceAll(':', '.')}.',
      confirmLabel: 'Ya, ambil selfie',
    );
    if (!yakin || !mounted) return;
    await _run(() async {
      // Selfie wajib (revisi owner 26 Nov 2026). Dibaca ke memori begitu kamera
      // kembali, sebelum berkas cache-nya sempat dibersihkan sistem.
      setState(() => _progress = 'Mengambil foto…');
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (shot == null) return;
      final photo = await shot.readAsBytes();
      setState(() => _progress = 'Mendeteksi lokasi…');
      double? lat, lng;
      try {
        final pos = await LocationHelper.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        // Lokasi pulang lembur hanya dicatat; tanpa GPS tetap boleh pulang.
      }
      setState(() => _progress = 'Menyimpan pulang lembur…');
      final done = await ref
          .read(attendanceRepositoryProvider)
          .overtimeCheckOut(id: ot.id, photo: photo, latitude: lat, longitude: lng);
      ref.invalidate(myOvertimesProvider);
      // Selesai lembur: cabang kembali mengikuti jadwal biasa.
      await _reloadBranch();
      _snack('Lembur selesai: ${done.hours} jam dibayar.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myOvertimesProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(title: const Text('Absen Lembur'), centerTitle: true),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(myOvertimesProvider),
              child: async.when(
                loading: SdmStateView.loading,
                error: (e, _) => SdmStateView(
                  icon: Icons.error_outline,
                  message: '$e',
                  onRetry: () => ref.invalidate(myOvertimesProvider),
                ),
                data: (rows) => ListView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
                  children: [
                    const SdmNote(
                      icon: Icons.info_outline,
                      text: 'Lembur dijadwalkan leader/SPV di jadwal. Absen pulang shift dulu, lalu masuk '
                          'ulang di lokasi lembur dengan selfie. Pulang lembur juga dengan selfie. Jam yang '
                          'dibayar dibatasi jam jadwal lembur.',
                    ),
                    const SizedBox(height: 16),
                    if (rows.isEmpty)
                      const SdmEmpty(icon: Icons.more_time, message: 'Tidak ada jadwal lembur hari ini dan seminggu ke depan.'),
                    for (final ot in rows) ...[
                      OvertimeCard(
                        ot: ot,
                        onCheckIn: _busy ? null : () => _checkIn(ot),
                        onCheckOut: _busy ? null : () => _checkOut(ot),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            if (_progress.isNotEmpty) ...[const SizedBox(height: 12), Text(_progress)],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Satu lembur: tanggal, jam, lokasi, status, dan tombol yang berlaku.
class OvertimeCard extends StatelessWidget {
  final ScheduledOvertime ot;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCheckOut;
  const OvertimeCard({super.key, required this.ot, this.onCheckIn, this.onCheckOut});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(ot.date);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final statusColor = ot.isCompleted
        ? AppTheme.brandGreenDark
        : ot.isActive
            ? const Color(0xFFEA580C)
            : AppTheme.textSecondary;
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(date == null ? ot.date : _day.format(date),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ),
              SdmPill(ot.statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text('Lembur ${ot.hoursLabel}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          Text(
            ot.crossLocation ? 'Di ${ot.location.name} (bantuan dari ${ot.home.name})' : 'Di ${ot.location.name}',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          if (ot.note.isNotEmpty)
            Text(ot.note, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          if (ot.checkInAt != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                'Masuk ulang ${_clock.format(ot.checkInAt!.toLocal())}',
                if (ot.checkOutAt != null) 'pulang ${_clock.format(ot.checkOutAt!.toLocal())}',
                if (ot.isCompleted) '${ot.hours} jam dibayar',
              ].join(' · '),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ],
          if (ot.isScheduled && ot.date.compareTo(today) <= 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCheckIn,
                icon: const Icon(Icons.photo_camera_front_outlined),
                label: const Text('Masuk ulang lembur'),
              ),
            ),
          ],
          if (ot.isActive) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCheckOut,
                icon: const Icon(Icons.logout),
                label: const Text('Pulang lembur'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kartu di layar Jadwal Saya (dan Absensi untuk role absensi-saja): muncul
/// hanya bila ada lembur terjadwal, membuka layar Absen Lembur.
class OvertimeEntryCard extends ConsumerWidget {
  const OvertimeEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(myOvertimesProvider).valueOrNull ?? const <ScheduledOvertime>[];
    final pending = [for (final r in rows) if (!r.isCompleted) r];
    if (pending.isEmpty) return const SizedBox.shrink();
    final first = pending.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SdmCard(
        color: const Color(0xFFFFF7ED),
        child: Row(
          children: [
            const Icon(Icons.more_time, color: Color(0xFFEA580C)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(first.isActive ? 'Sedang lembur' : 'Ada jadwal lembur',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                  Text('${first.hoursLabel} di ${first.location.name}'
                      '${pending.length > 1 ? ' · +${pending.length - 1} lagi' : ''}',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OvertimePage())),
              child: const Text('Absen Lembur'),
            ),
          ],
        ),
      ),
    );
  }
}
