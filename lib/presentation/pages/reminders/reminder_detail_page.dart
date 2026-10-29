import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/reminder_model.dart';
import 'package:pos_mobile/data/services/push_service.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _clock = DateFormat('HH.mm', 'id_ID');
final _when = DateFormat('EEE d MMM, HH.mm', 'id_ID');

const _dutyLabels = {'cashier': 'Kasir', 'server': 'Penyaji'};

/// Warna status penerima, sama dengan web admin.
Color reminderStatusColor(String status) => switch (status) {
  'pending' => const Color(0xFFD97706),
  'read' || 'replied' => const Color(0xFF15803D),
  'incomplete' => const Color(0xFFEA580C),
  'missed' => AppTheme.danger,
  _ => AppTheme.textSecondary,
};

/// Satu reminder untuk penerimanya (Tahap 4, F11): catatan ditandai sudah
/// dibaca, permintaan pengecekan dibalas foto per bagian dari kamera.
///
/// Juga tujuan ketukan notifikasi `app:/reminders/<id>`, termasuk alarm yang
/// membuka app di atas kunci layar.
class ReminderDetailPage extends ConsumerStatefulWidget {
  final int reminderId;
  const ReminderDetailPage({super.key, required this.reminderId});

  @override
  ConsumerState<ReminderDetailPage> createState() => _ReminderDetailPageState();
}

class _ReminderDetailPageState extends ConsumerState<ReminderDetailPage> {
  MyReminder? _r;
  Object? _error;
  DateTime _fetchedAt = DateTime.now();
  final _uploading = <int>{};
  bool _marking = false;
  bool _reloadedAfterDeadline = false;
  Timer? _tick;

  int get _id => widget.reminderId;

  @override
  void initState() {
    super.initState();
    // Alarm berhenti berbunyi begitu layarnya terbuka.
    PushService.cancelTag('reminder-$_id');
    _load(open: true);
  }

  @override
  void dispose() {
    _tick?.cancel();
    PushService.releaseLockScreen();
    super.dispose();
  }

  /// `open` mencatat waktu baca dan sekaligus mengembalikan isinya; aman
  /// diulang, jadi dipakai juga saat layar dibuka dari daftar.
  Future<void> _load({bool open = false}) async {
    final repo = ref.read(reminderRepositoryProvider);
    try {
      _apply(open ? await repo.open(_id) : await repo.one(_id));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _apply(MyReminder r) {
    if (!mounted) return;
    setState(() {
      _r = r;
      _error = null;
      _fetchedAt = DateTime.now();
    });
    refreshReminders(ref);
    _tick?.cancel();
    if (r.isCheck && r.isPending && r.deadlineAt != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    }
  }

  /// Sisa waktu menurut jam server: `deadline − server_time`, dikurangi waktu
  /// sejak jawaban itu diterima. Jam HP yang salah tidak memengaruhinya.
  Duration? get _remaining {
    final r = _r;
    if (r?.deadlineAt == null) return null;
    final server = r!.serverTime ?? _fetchedAt;
    return r.deadlineAt!.difference(server) - DateTime.now().difference(_fetchedAt);
  }

  void _onTick() {
    final left = _remaining;
    if (left != null && left <= Duration.zero) {
      _tick?.cancel();
      // Sekali, untuk mengambil status akhirnya (kurang / tidak dibalas).
      if (!_reloadedAfterDeadline) {
        _reloadedAfterDeadline = true;
        _load();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _shoot(ReminderPart part) async {
    // Kamera saja, tanpa pilihan galeri: fotonya harus diambil saat itu.
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (file == null || !mounted) return;
    // Dibaca ke memori sekarang juga, sebelum folder cache kamera sempat
    // dikosongkan Android.
    final bytes = await file.readAsBytes();
    setState(() => _uploading.add(part.id));
    try {
      final r = await ref
          .read(reminderRepositoryProvider)
          .uploadPhoto(_id, partId: part.id, bytes: bytes, filename: 'reminder-$_id-${part.id}.jpg');
      _apply(r);
      if (r.status == 'replied') _snack('Semua bagian sudah terkirim. Terima kasih!');
    } catch (e) {
      _snack('$e', error: true);
      // Tenggat bisa saja lewat saat kamera terbuka; ambil status terbarunya.
      _load();
    } finally {
      if (mounted) setState(() => _uploading.remove(part.id));
    }
  }

  Future<void> _markRead() async {
    setState(() => _marking = true);
    try {
      _apply(await ref.read(reminderRepositoryProvider).markRead(_id));
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(r == null ? 'Reminder' : (r.isCheck ? 'Pengecekan Foto' : 'Catatan')),
        centerTitle: true,
      ),
      body: r == null
          ? (_error == null
              ? SdmStateView.loading()
              : SdmStateView(icon: Icons.error_outline, message: '$_error', onRetry: () => _load(open: true)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
                children: [
                  _Header(r: r),
                  const SizedBox(height: 12),
                  if (r.isCheck) ...[
                    _CheckState(r: r, remaining: _remaining),
                    const SizedBox(height: 20),
                    Text(
                      'Bagian yang difoto (${r.photographed}/${r.parts.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    for (final part in r.parts) ...[
                      _PartCard(
                        part: part,
                        uploading: _uploading.contains(part.id),
                        canShoot: r.isPending &&
                            (_remaining ?? Duration.zero) > Duration.zero &&
                            !(part.photo?.judged ?? false),
                        onShoot: () => _shoot(part),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (r.isPending) ...[
                      const SizedBox(height: 4),
                      const SdmNote(
                        icon: Icons.photo_camera_outlined,
                        text: 'Foto langsung dari kamera. Tiap foto terkirim begitu diambil, dan bisa '
                            'diulang selama waktu belum habis dan belum dinilai.',
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 8),
                    if (r.isPending)
                      ElevatedButton.icon(
                        onPressed: _marking ? null : _markRead,
                        icon: _marking
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.done_all),
                        label: const Text('Sudah dibaca'),
                      )
                    else
                      SdmNote(
                        icon: Icons.done_all,
                        text: r.readAt == null ? 'Sudah dibaca.' : 'Dibaca ${_clock.format(r.readAt!.toLocal())}.',
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final MyReminder r;
  const _Header({required this.r});

  @override
  Widget build(BuildContext context) {
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(r.isCheck ? Icons.photo_camera_outlined : Icons.campaign_outlined, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [r.senderName, if (r.branchName.isNotEmpty) r.branchName].join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
              SdmPill(reminderStatusLabels[r.status] ?? r.status, color: reminderStatusColor(r.status)),
            ],
          ),
          if (r.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Dikirim ${_when.format(r.createdAt!.toLocal())}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
          if (r.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(r.message, style: const TextStyle(fontSize: 16, height: 1.4, color: AppTheme.textPrimary)),
          ],
        ],
      ),
    );
  }
}

/// Hitung mundur selama masih bisa dibalas; ringkasan akhirnya sesudah itu.
class _CheckState extends StatelessWidget {
  final MyReminder r;
  final Duration? remaining;
  const _CheckState({required this.r, required this.remaining});

  @override
  Widget build(BuildContext context) {
    if (!r.isPending) {
      final text = switch (r.status) {
        'replied' => r.repliedAt == null
            ? 'Semua bagian sudah difoto.'
            : 'Semua bagian sudah difoto, ${_clock.format(r.repliedAt!.toLocal())}.',
        'incomplete' => 'Waktu habis. Sebagian bagian belum difoto.',
        'missed' => 'Waktu habis. Tidak ada foto yang terkirim.',
        _ => reminderStatusLabels[r.status] ?? r.status,
      };
      return SdmNote(icon: Icons.flag_outlined, text: text, warning: r.status != 'replied');
    }
    final left = remaining ?? Duration.zero;
    final secs = left.inSeconds.clamp(0, 24 * 3600);
    final urgent = secs < 180;
    final color = urgent ? AppTheme.danger : const Color(0xFFD97706);
    final mmss = '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  secs == 0 ? 'Waktu habis' : 'Sisa $mmss',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
                ),
                if (r.deadlineAt != null)
                  Text(
                    'Batas balas ${_clock.format(r.deadlineAt!.toLocal())}',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  final ReminderPart part;
  final bool uploading;
  final bool canShoot;
  final VoidCallback onShoot;
  const _PartCard({required this.part, required this.uploading, required this.canShoot, required this.onShoot});

  @override
  Widget build(BuildContext context) {
    final photo = part.photo;
    final status = photo == null
        ? 'Belum difoto'
        : switch (photo.verdict) {
            'clean' => 'Dinilai bersih',
            'dirty' => 'Dinilai kotor',
            _ => photo.receivedAt == null
                ? 'Terkirim'
                : 'Terkirim ${_clock.format(photo.receivedAt!.toLocal())}',
          };
    return SdmCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: photo == null
                  ? const ColoredBox(
                      color: AppTheme.bgLight,
                      child: Icon(Icons.image_outlined, color: AppTheme.textSecondary),
                    )
                  : Image.network(
                      photo.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppTheme.bgLight,
                        child: Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(part.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${_dutyLabels[part.duty] ?? part.duty} · $status',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: photo?.verdict == 'dirty' ? AppTheme.danger : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (uploading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else if (canShoot)
            ElevatedButton.icon(
              onPressed: onShoot,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
              icon: const Icon(Icons.photo_camera, size: 18),
              label: Text(photo == null ? 'Foto' : 'Ulang'),
            ),
        ],
      ),
    );
  }
}
