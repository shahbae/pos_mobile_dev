import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/kpi_revisi_model.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _when = DateFormat('EEE d MMM, HH.mm', 'id_ID');
final _month = DateFormat('MMMM y', 'id_ID');

String _period(String p) {
  final d = DateTime.tryParse('$p-01');
  return d == null ? p : _month.format(d);
}

/// Arahan dan evaluasi dari SPV untuk leader (revisi KPI 11 Nov, SPV-A2).
/// SPV memberi arahan bertenggat lewat web; leader menandainya sudah
/// dikerjakan (catatan/foto opsional) sebelum SPV mengeceknya. Evaluasi
/// bulanan hanya dibaca.
class DirectivesPage extends ConsumerStatefulWidget {
  /// 0 = Arahan, 1 = Evaluasi.
  final int initialTab;
  const DirectivesPage({super.key, this.initialTab = 0});

  @override
  ConsumerState<DirectivesPage> createState() => _DirectivesPageState();
}

class _DirectivesPageState extends ConsumerState<DirectivesPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: const Text('Arahan SPV'),
          centerTitle: true,
          bottom: const TabBar(tabs: [Tab(text: 'Arahan'), Tab(text: 'Evaluasi')]),
        ),
        body: const TabBarView(children: [_DirectiveList(), _EvaluationList()]),
      ),
    );
  }
}

class _DirectiveList extends ConsumerWidget {
  const _DirectiveList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myDirectivesProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myDirectivesProvider),
      child: async.when(
        loading: SdmStateView.loading,
        error: (e, _) => SdmStateView(icon: Icons.cloud_off, message: '$e', onRetry: () => ref.invalidate(myDirectivesProvider)),
        data: (rows) => rows.isEmpty
            ? const SdmStateView(icon: Icons.assignment_outlined, message: 'Belum ada arahan dari SPV.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final d in rows) ...[
                    DirectiveTile(directive: d),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Satu arahan; terpisah supaya bisa diuji tanpa jaringan.
class DirectiveTile extends ConsumerWidget {
  final LeaderDirective directive;
  final DateTime? now;
  const DirectiveTile({super.key, required this.directive, this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = directive;
    final overdue = !d.isChecked && d.doneAt == null && d.dueAt != null && d.dueAt!.isBefore(now ?? DateTime.now());
    final color = d.isChecked
        ? (d.checkResult == 'done' ? const Color(0xFF15803D) : AppTheme.danger)
        : (d.doneAt != null ? AppTheme.brandBlue : (overdue ? AppTheme.danger : const Color(0xFFD97706)));
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SdmPill(overdue ? 'Lewat tenggat' : d.stateLabel, color: color)),
              if (d.photoUrl != null) KpiThumb(d.photoUrl!, size: 40),
            ],
          ),
          const SizedBox(height: 10),
          Text(d.content, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
            [
              if (d.spvName.isNotEmpty) 'Dari ${d.spvName}',
              if (d.dueAt != null) 'tenggat ${_when.format(d.dueAt!)}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (d.doneAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ditandai dikerjakan ${_when.format(d.doneAt!)}${d.doneNote.isEmpty ? '' : ': ${d.doneNote}'}',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
            ),
            if (d.donePhotoUrl != null) Padding(padding: const EdgeInsets.only(top: 6), child: KpiThumb(d.donePhotoUrl!, size: 48)),
          ],
          if (d.isChecked && d.checkNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Catatan SPV: ${d.checkNote}', style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary)),
          ],
          if (d.canMarkDone) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: d.doneAt == null
                  ? ElevatedButton.icon(
                      onPressed: () => _markDone(context, ref, d),
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Sudah dikerjakan'),
                    )
                  : OutlinedButton(
                      onPressed: () => _markDone(context, ref, d),
                      child: const Text('Perbarui catatan / foto'),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markDone(BuildContext context, WidgetRef ref, LeaderDirective d) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MarkDoneSheet(directive: d),
    );
    if (done == true) ref.invalidate(myDirectivesProvider);
  }
}

class _MarkDoneSheet extends ConsumerStatefulWidget {
  final LeaderDirective directive;
  const _MarkDoneSheet({required this.directive});

  @override
  ConsumerState<_MarkDoneSheet> createState() => _MarkDoneSheetState();
}

class _MarkDoneSheetState extends ConsumerState<_MarkDoneSheet> {
  late final _note = TextEditingController(text: widget.directive.doneNote);
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(kpiRepositoryProvider).markDirectiveDone(widget.directive.id, note: _note.text, photo: _photo);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tandai sudah dikerjakan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(widget.directive.content, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)', hintText: 'mis. rak sudah dirapikan pagi ini'),
            ),
            const SizedBox(height: 8),
            if (_photo != null)
              KpiPhotoPreview(_photo!, height: 140, onRemove: _busy ? null : () => setState(() => _photo = null))
            else
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final b = await pickKpiPhoto(context);
                        if (b != null && mounted) setState(() => _photo = b);
                      },
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Foto bukti (opsional)'),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationList extends ConsumerWidget {
  const _EvaluationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myEvaluationsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myEvaluationsProvider),
      child: async.when(
        loading: SdmStateView.loading,
        error: (e, _) => SdmStateView(icon: Icons.cloud_off, message: '$e', onRetry: () => ref.invalidate(myEvaluationsProvider)),
        data: (rows) => rows.isEmpty
            ? const SdmStateView(icon: Icons.rate_review_outlined, message: 'Belum ada evaluasi bulanan dari SPV.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final e in rows) ...[
                    SdmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Evaluasi ${_period(e.period)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                                ),
                              ),
                              if (e.photoUrl != null) KpiThumb(e.photoUrl!, size: 44),
                            ],
                          ),
                          if (e.spvName.isNotEmpty)
                            Text('Dari ${e.spvName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 10),
                          Text(e.content, style: const TextStyle(color: AppTheme.textPrimary, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Kartu Beranda leader: arahan SPV yang belum ditandai dikerjakan.
class DirectivesCard extends ConsumerWidget {
  const DirectivesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canSeeDirectives(ref.watch(authProvider).held)) return const SizedBox.shrink();
    final rows = ref.watch(myDirectivesProvider).valueOrNull ?? const <LeaderDirective>[];
    final open = rows.where((d) => d.isOpen).toList();
    if (open.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final late = open.where((d) => d.dueAt != null && d.dueAt!.isBefore(now)).length;
    final color = late > 0 ? AppTheme.danger : AppTheme.brandBlue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectivesPage()));
            ref.invalidate(myDirectivesProvider);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${open.length} arahan SPV belum dikerjakan', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                      const SizedBox(height: 2),
                      Text(
                        late > 0 ? '$late sudah lewat tenggat' : open.first.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
