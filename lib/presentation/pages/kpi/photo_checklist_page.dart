import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/repositories/kpi_repository.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _hm = DateFormat('HH.mm', 'id_ID');
final _day = DateFormat('EEEE d MMM', 'id_ID');

const checklistStatusLabels = {
  'missing': 'Belum',
  'pending': 'Menunggu ACC',
  'approved': 'Di-ACC',
  'rejected': 'Ditolak',
};

Color checklistStatusColor(String status) => switch (status) {
  'pending' => const Color(0xFFD97706),
  'approved' => const Color(0xFF15803D),
  'rejected' => AppTheme.danger,
  _ => AppTheme.textSecondary,
};

/// Ceklis foto opening & closing shift hari ini (Tahap 6, C1.1/C2.1/C5.4a).
/// Satu set per outlet × shift × tugas; kiriman rekan di set yang sama ikut
/// tampil, jadi satu butir cukup difoto satu orang.
class PhotoChecklistPage extends ConsumerStatefulWidget {
  /// Hanya fase ini yang dibuka di atas (mis. `closing` dari Tutup Shift).
  final String? focusPhase;
  const PhotoChecklistPage({super.key, this.focusPhase});

  @override
  ConsumerState<PhotoChecklistPage> createState() => _PhotoChecklistPageState();
}

class _PhotoChecklistPageState extends ConsumerState<PhotoChecklistPage> {
  /// `scheduleId:itemId` yang sedang dikirim.
  final _sending = <String>{};

  /// `itemId` deep cleaning yang sedang dikirim.
  final _sendingDeep = <int>{};

  Future<void> _shootDeep(DeepCleanItem i) async {
    final bytes = await pickKpiPhoto(context);
    if (bytes == null || !mounted) return;
    setState(() => _sendingDeep.add(i.itemId));
    try {
      await ref.read(kpiRepositoryProvider).submitDeepClean(itemId: i.itemId, photo: bytes);
      _snack('${i.name} terkirim.');
    } on KpiApiError catch (e) {
      // Rekan di outlet yang sama sudah memfoto butir ini: itu bukan galat.
      final dup = e.code == 'deep_clean_already_sent' || e.code == 'deep_clean_approved';
      _snack(dup ? '${i.name} sudah difoto rekanmu minggu ini.' : e.message, error: !dup);
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) {
        setState(() => _sendingDeep.remove(i.itemId));
        ref.invalidate(myDeepCleanProvider);
      }
    }
  }

  String _key(ChecklistSet s, ChecklistItemState i) => '${s.scheduleId}:${s.duty}:${i.itemId}';

  Future<void> _shoot(ChecklistSet s, ChecklistItemState i) async {
    final bytes = await pickKpiPhoto(context);
    if (bytes == null || !mounted) return;
    await _send(s, i, () => ref.read(kpiRepositoryProvider).submitChecklist(
          scheduleId: s.scheduleId,
          itemId: i.itemId,
          photo: bytes,
        ));
  }

  Future<void> _markUnused(ChecklistSet s, ChecklistItemState i) async {
    final reason = await _askUnusedReason(context, i.name);
    if (reason == null || !mounted) return;
    await _send(s, i, () => ref.read(kpiRepositoryProvider).submitChecklist(
          scheduleId: s.scheduleId,
          itemId: i.itemId,
          unusedReason: reason,
        ));
  }

  Future<void> _send(ChecklistSet s, ChecklistItemState i, Future<void> Function() call) async {
    final k = _key(s, i);
    setState(() => _sending.add(k));
    try {
      await call();
      _snack('${i.name} terkirim.');
    } on KpiApiError catch (e) {
      // Rekan di set yang sama baru saja mengirim butir ini: tampilkan
      // kirimannya, bukan galat.
      _snack(e.code == 'checklist_already_sent' ? '${i.name} sudah dikirim rekanmu.' : e.message,
          error: e.code != 'checklist_already_sent');
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) {
        setState(() => _sending.remove(k));
        ref.invalidate(myChecklistProvider);
      }
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
    final async = ref.watch(myChecklistProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Ceklis Foto'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myChecklistProvider);
          ref.invalidate(myDeepCleanProvider);
        },
        child: async.when(
          // Saat memuat ulang sesudah kirim, daftar lama tetap tampil.
          skipLoadingOnRefresh: true,
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(
            icon: Icons.error_outline,
            message: '$e',
            onRetry: () => ref.invalidate(myChecklistProvider),
          ),
          data: (sets) => ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottomInset),
            children: [
              if (sets.isEmpty)
                const SdmEmpty(
                  icon: Icons.photo_camera_outlined,
                  message: 'Tidak ada ceklis foto untuk shiftmu hari ini.',
                )
              else ...[
                const SdmNote(
                  icon: Icons.info_outline,
                  text: 'Foto langsung dari kamera. Satu butir cukup difoto satu orang di shift yang sama. '
                      'Yang ditolak SPV bisa dikirim ulang selama batas kirim belum lewat.',
                ),
                const SizedBox(height: 16),
                for (final s in sets) ...[
                  _SetCard(
                    set: s,
                    focusPhase: widget.focusPhase,
                    sending: (i) => _sending.contains(_key(s, i)),
                    onShoot: (i) => _shoot(s, i),
                    onUnused: (i) => _markUnused(s, i),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              _DeepCleanCard(sending: _sendingDeep, onShoot: _shootDeep),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu deep cleaning mingguan outlet. Muat sendiri: galatnya (belum ada
/// jadwal, jaringan) hanya tampil di kartu ini, tidak di ceklis harian.
class _DeepCleanCard extends ConsumerWidget {
  final Set<int> sending;
  final void Function(DeepCleanItem) onShoot;

  const _DeepCleanCard({required this.sending, required this.onShoot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myDeepCleanProvider);
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const SdmCard(child: Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))),
      error: (e, _) => SdmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deep cleaning mingguan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('$e', style: const TextStyle(color: AppTheme.textSecondary)),
            TextButton(onPressed: () => ref.invalidate(myDeepCleanProvider), child: const Text('Coba lagi')),
          ],
        ),
      ),
      data: (set) => SdmCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deep cleaning mingguan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(
              [
                set.branchName,
                if (set.weekStart.isNotEmpty) 'minggu ${_dayMonth(set.weekStart)} – ${_dayMonth(set.weekEnd)}',
              ].where((x) => x.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (!set.scored) const SdmPill('Belum dinilai KPI'),
                if (set.deadline != null) SdmPill('Batas ${_day.format(set.deadline!.toLocal())}, ${_hm.format(set.deadline!.toLocal())}'),
              ],
            ),
            if (set.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Belum ada butir deep cleaning. Owner atau SPV mengisinya di web admin.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Difoto ${set.sent}/${set.total} · di-ACC ${set.approved}. Satu butir cukup difoto satu orang di outlet ini; '
                'yang ditolak bisa difoto ulang sampai batas.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              for (final i in set.items)
                _DeepCleanRow(item: i, sending: sending.contains(i.itemId), onShoot: () => onShoot(i)),
            ],
          ],
        ),
      ),
    );
  }
}

String _dayMonth(String ymd) {
  final d = DateTime.tryParse(ymd);
  return d == null ? ymd : DateFormat('d MMM', 'id_ID').format(d);
}

class _DeepCleanRow extends StatelessWidget {
  final DeepCleanItem item;
  final bool sending;
  final VoidCallback onShoot;

  const _DeepCleanRow({required this.item, required this.sending, required this.onShoot});

  @override
  Widget build(BuildContext context) {
    final i = item;
    final by = [
      if (i.uploadedByName != null) i.uploadedByName!,
      if (i.takenAt != null) _hm.format(i.takenAt!.toLocal()),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i.photoUrl != null) ...[
                KpiThumb(i.photoUrl!, size: 52),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    SdmPill(checklistStatusLabels[i.status] ?? i.status, color: checklistStatusColor(i.status)),
                    if (by.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(by, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                    if (i.status == 'rejected' && i.rejectReason.isNotEmpty)
                      Text('Ditolak: ${i.rejectReason}', style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
                  ],
                ),
              ),
            ],
          ),
          if (!i.isSent) ...[
            const SizedBox(height: 8),
            // Tombol di bawah baris, selebar kartu (pelajaran revisi uji 31 Okt).
            if (sending)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onShoot,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(i.status == 'rejected' ? 'Foto ulang' : 'Ambil foto'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

Future<String?> _askUnusedReason(BuildContext context, String name) =>
    showDialog<String>(context: context, builder: (_) => _UnusedReasonDialog(name: name));

/// Dialog alasan "belum dipakai". Controller dipegang State dialog sendiri:
/// dibuang saat Future showDialog selesai, animasi tutupnya masih membangun
/// ulang TextField dengan controller yang sudah dibuang.
class _UnusedReasonDialog extends StatefulWidget {
  final String name;
  const _UnusedReasonDialog({required this.name});

  @override
  State<_UnusedReasonDialog> createState() => _UnusedReasonDialogState();
}

class _UnusedReasonDialogState extends State<_UnusedReasonDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('${widget.name} belum dipakai'),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Alasan', hintText: 'mis. Masih baru, belum dipakai hari ini.'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: _c.text.trim().isEmpty ? null : () => Navigator.pop(context, _c.text.trim()),
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}

class _SetCard extends StatelessWidget {
  final ChecklistSet set;
  final String? focusPhase;
  final bool Function(ChecklistItemState) sending;
  final void Function(ChecklistItemState) onShoot;
  final void Function(ChecklistItemState) onUnused;

  const _SetCard({
    required this.set,
    required this.focusPhase,
    required this.sending,
    required this.onShoot,
    required this.onUnused,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(set.date);
    final phases = [...set.phases];
    if (focusPhase != null) {
      phases.sort((a, b) => (a.phase == focusPhase ? 0 : 1).compareTo(b.phase == focusPhase ? 0 : 1));
    }
    return SdmCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${set.shiftName} · ${checklistDutyLabels[set.duty] ?? set.duty}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            [set.branchName, if (date != null) _day.format(date)].where((x) => x.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          if (!set.judged) ...[
            const SizedBox(height: 8),
            const SdmPill('Belum dinilai KPI'),
          ],
          for (final p in phases) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _PhaseBlock(phase: p, sending: sending, onShoot: onShoot, onUnused: onUnused),
          ],
        ],
      ),
    );
  }
}

class _PhaseBlock extends StatelessWidget {
  final ChecklistPhase phase;
  final bool Function(ChecklistItemState) sending;
  final void Function(ChecklistItemState) onShoot;
  final void Function(ChecklistItemState) onUnused;

  const _PhaseBlock({required this.phase, required this.sending, required this.onShoot, required this.onUnused});

  String get _window {
    final now = DateTime.now();
    final opens = phase.opensAt?.toLocal();
    final deadline = phase.deadline?.toLocal();
    final cutoff = phase.cutoff?.toLocal();
    if (opens != null && now.isBefore(opens)) return 'Dibuka pukul ${_hm.format(opens)}';
    if (cutoff != null && !now.isBefore(cutoff)) return 'Batas kirim ${_hm.format(cutoff)} sudah lewat';
    return [
      if (deadline != null) 'tepat waktu sampai ${_hm.format(deadline)}',
      if (cutoff != null) 'batas kirim ${_hm.format(cutoff)}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${checklistPhaseLabels[phase.phase] ?? phase.phase} (${phase.sentCount}/${phase.items.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ),
            if (phase.complete) const SdmPill('Lengkap', color: Color(0xFF15803D)),
          ],
        ),
        if (_window.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(_window, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
        const SizedBox(height: 8),
        for (final i in phase.items)
          _ItemRow(
            item: i,
            canSubmit: phase.isOpenAt(DateTime.now()) && !i.isSent,
            sending: sending(i),
            onShoot: () => onShoot(i),
            onUnused: () => onUnused(i),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ChecklistItemState item;

  /// Dari jam fase di HP, bukan `can_submit` saat dimuat (lihat
  /// [ChecklistPhase.isOpenAt]).
  final bool canSubmit;
  final bool sending;
  final VoidCallback onShoot;
  final VoidCallback onUnused;

  const _ItemRow({
    required this.item,
    required this.canSubmit,
    required this.sending,
    required this.onShoot,
    required this.onUnused,
  });

  @override
  Widget build(BuildContext context) {
    final i = item;
    final by = [
      if (i.uploadedByName != null) i.uploadedByName!,
      if (i.takenAt != null) _hm.format(i.takenAt!.toLocal()),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i.photoUrl != null) ...[
                KpiThumb(i.photoUrl!, size: 52),
                const SizedBox(width: 10),
              ] else if (i.unused) ...[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: AppTheme.bgLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.do_not_disturb_alt_outlined, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        SdmPill(checklistStatusLabels[i.status] ?? i.status, color: checklistStatusColor(i.status)),
                        if (i.late) const SdmPill('Terlambat', color: AppTheme.danger),
                        if (i.unused) const SdmPill('Belum dipakai'),
                      ],
                    ),
                    if (by.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(by, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                    if (i.unused && i.unusedReason.isNotEmpty)
                      Text(i.unusedReason, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    if (i.status == 'rejected' && i.rejectReason.isNotEmpty)
                      Text('Ditolak: ${i.rejectReason}', style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
                  ],
                ),
              ),
            ],
          ),
          if (canSubmit) ...[
            const SizedBox(height: 8),
            // Tombol di bawah baris, selebar kartu: tombol bertema lebar penuh
            // di dalam Row pernah hilang dari layar (revisi uji 31 Okt).
            if (sending)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onShoot,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(i.status == 'rejected' ? 'Foto ulang' : 'Ambil foto'),
                ),
              ),
              if (i.allowUnused)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(onPressed: onUnused, child: const Text('Belum dipakai')),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
