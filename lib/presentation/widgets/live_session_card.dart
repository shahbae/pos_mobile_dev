import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/kpi_revisi_model.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';

final _clock = DateFormat('HH.mm', 'id_ID');

/// Kartu Beranda "Live TikTok" (revisi KPI 11 Nov, C3.4). Tampil bila orang
/// yang login dijadwalkan Live kemarin (shift belum berakhir) atau hari ini.
/// Mulai ditekan saat Live dimulai; Selesai ditekan saat Live berakhir dengan
/// screenshot ringkasan TikTok. Sesudah shift berakhir sistem menilai: sesi
/// bermasalah mendapat usulan potongan yang baru berlaku bila SPV menyetujui.
class LiveSessionCard extends ConsumerStatefulWidget {
  const LiveSessionCard({super.key});

  @override
  ConsumerState<LiveSessionCard> createState() => _LiveSessionCardState();
}

class _LiveSessionCardState extends ConsumerState<LiveSessionCard> with WidgetsBindingObserver {
  Timer? _tick;
  int? _busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(minutes: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (mounted && canDoLive(ref.read(authProvider).held)) ref.invalidate(myLiveSessionsProvider);
  }

  Future<void> _run(LiveSlot slot, Future<void> Function() action, String done) async {
    setState(() => _busy = slot.scheduleId);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _busy = null);
      _refresh();
    }
  }

  Future<void> _start(LiveSlot slot) async {
    final ok = await confirmAction(
      context,
      title: 'Mulai Live sekarang?',
      message: 'Tekan saat Live TikTok benar-benar dimulai. Live dinilai minimal 60 menit dan di dalam jam shift.',
      confirmLabel: 'Ya, mulai',
    );
    if (!ok || !mounted) return;
    await _run(slot, () => ref.read(kpiRepositoryProvider).startLive(slot.scheduleId), 'Live dimulai. Tekan Selesai saat Live berakhir.');
  }

  Future<void> _photo(LiveSlot slot, {required bool finish}) async {
    final session = slot.session;
    if (session == null) return;
    final bytes = await pickKpiPhotoAnySource(context);
    if (bytes == null || !mounted) return;
    final repo = ref.read(kpiRepositoryProvider);
    await _run(
      slot,
      () => finish ? repo.finishLive(session.id, bytes) : repo.addLiveScreenshot(session.id, bytes),
      finish ? 'Live selesai. Screenshot terkirim.' : 'Screenshot terkirim.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!canDoLive(ref.watch(authProvider).held)) return const SizedBox.shrink();
    final slots = (ref.watch(myLiveSessionsProvider).valueOrNull ?? const <LiveSlot>[])
        .where((s) => s.actionable || s.session != null)
        .toList();
    if (slots.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final s in slots)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: LiveSlotTile(
              slot: s,
              busy: _busy == s.scheduleId,
              onStart: () => _start(s),
              onFinish: () => _photo(s, finish: true),
              onScreenshot: () => _photo(s, finish: false),
            ),
          ),
      ],
    );
  }
}

/// Isi kartu satu jadwal Live; terpisah supaya bisa diuji tanpa jaringan.
class LiveSlotTile extends StatelessWidget {
  final LiveSlot slot;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onFinish;
  final VoidCallback onScreenshot;

  const LiveSlotTile({
    super.key,
    required this.slot,
    this.busy = false,
    required this.onStart,
    required this.onFinish,
    required this.onScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    final s = slot.session;
    const pink = Color(0xFFBE185D);
    final shift = [
      if (slot.shiftName.isNotEmpty) slot.shiftName,
      if (slot.shiftStart != null && slot.shiftEnd != null) '${_clock.format(slot.shiftStart!)}–${_clock.format(slot.shiftEnd!)}',
    ].join(' ');
    final lines = <String>[
      if (s == null && slot.canStart) 'Tekan Mulai saat Live dimulai, Selesai saat berakhir (minimal 60 menit, di dalam jam shift).',
      if (s != null && s.running) 'Live berjalan sejak ${_clock.format(s.startedAt!)}. Tekan Selesai saat Live berakhir.',
      if (s != null && !s.running && s.startedAt != null)
        'Live ${_clock.format(s.startedAt!)}–${s.endedAt == null ? '?' : _clock.format(s.endedAt!)}'
            '${s.durationMinutes == null ? '' : ' (${s.durationMinutes} menit)'}'
            '${s.closedBySystem ? ', ditutup sistem karena Selesai tidak ditekan' : ''}.',
      if (s != null && s.problemLabel.isNotEmpty) 'Penilaian: ${s.problemLabel}.',
      if (s != null && s.verdictLabel.isNotEmpty) '${s.verdictLabel}.',
      if (s != null && s.screenshotUrl == null && slot.canAddScreenshot) 'Screenshot ringkasan TikTok belum ada, kirim sekarang.',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pink.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.live_tv_rounded, color: pink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Live TikTok${shift.isEmpty ? '' : ' · $shift'}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: pink),
                ),
              ),
              if (s?.screenshotUrl != null) KpiThumb(s!.screenshotUrl!, size: 36),
            ],
          ),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151))),
            ),
          if (slot.canAddScreenshot && !slot.canStart && !slot.canFinish && s?.screenshotUrl != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : onScreenshot,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Kirim screenshot susulan'),
                style: TextButton.styleFrom(foregroundColor: pink, padding: EdgeInsets.zero),
              ),
            )
          else if (slot.actionable) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: busy
                  ? null
                  : slot.canStart
                      ? onStart
                      : slot.canFinish
                          ? onFinish
                          : onScreenshot,
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(slot.canStart ? Icons.play_arrow_rounded : Icons.photo_library_outlined),
              label: Text(
                slot.canStart
                    ? 'Mulai Live'
                    : slot.canFinish
                        ? 'Selesai + screenshot'
                        : 'Kirim screenshot',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
