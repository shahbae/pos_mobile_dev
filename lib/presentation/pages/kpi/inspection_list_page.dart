import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/presentation/pages/kpi/inspection_form_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _when = DateFormat('EEE d MMM yyyy, HH.mm', 'id_ID');

/// Sidak outlet (Tahap 6, L6) — owner & SPV. Hanya sidak pertama tiap
/// outlet per minggu (Senin–Minggu) yang dinilai.
class InspectionListPage extends ConsumerWidget {
  const InspectionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inspectionsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Sidak'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final done = await Navigator.push<Inspection>(
            context,
            MaterialPageRoute(builder: (_) => const InspectionFormPage()),
          );
          if (done == null || !context.mounted) return;
          ref.invalidate(inspectionsProvider);
          Navigator.push(context, MaterialPageRoute(builder: (_) => InspectionDetailPage(inspectionId: done.id)));
        },
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Mulai sidak'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(inspectionsProvider),
        child: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(
            icon: Icons.error_outline,
            message: '$e',
            onRetry: () => ref.invalidate(inspectionsProvider),
          ),
          data: (rows) => ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 96 + bottomInset),
            children: [
              const SdmNote(
                icon: Icons.info_outline,
                text: 'Sidak dilakukan di outlet: lokasi HP harus dalam radius absensi outlet. '
                    'Hanya sidak pertama tiap outlet per minggu (Senin–Minggu) yang dinilai.',
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const SdmEmpty(icon: Icons.fact_check_outlined, message: 'Belum ada sidak.')
              else
                for (final i in rows) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => InspectionDetailPage(inspectionId: i.id)),
                    ),
                    child: _InspectionCard(i: i),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final Inspection i;
  const _InspectionCard({required this.i});

  @override
  Widget build(BuildContext context) {
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(i.branchName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ),
              SdmPill(
                i.failedCount == 0 ? 'Semua sesuai' : '${i.failedCount} tidak sesuai',
                color: i.failedCount == 0 ? const Color(0xFF15803D) : AppTheme.danger,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [if (i.at != null) _when.format(i.at!.toLocal()), i.inspectorName].where((x) => x.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (!i.scored) ...[
            const SizedBox(height: 6),
            const SdmPill('Tidak dinilai (bukan sidak pertama minggu itu)'),
          ],
        ],
      ),
    );
  }
}

final inspectionDetailProvider = FutureProvider.autoDispose.family<Inspection, int>((ref, id) {
  return ref.watch(kpiRepositoryProvider).inspection(id);
});

class InspectionDetailPage extends ConsumerWidget {
  final int inspectionId;
  const InspectionDetailPage({super.key, required this.inspectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inspectionDetailProvider(inspectionId));
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Hasil Sidak'), centerTitle: true),
      body: async.when(
        loading: SdmStateView.loading,
        error: (e, _) => SdmStateView(
          icon: Icons.error_outline,
          message: '$e',
          onRetry: () => ref.invalidate(inspectionDetailProvider(inspectionId)),
        ),
        data: (i) {
          final groups = <String, List<InspectionResult>>{};
          for (final r in i.results) {
            groups.putIfAbsent(r.group, () => []).add(r);
          }
          final order = [
            for (final g in inspectionGroupOrder)
              if (groups.containsKey(g)) g,
            for (final g in groups.keys)
              if (!inspectionGroupOrder.contains(g)) g,
          ];
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottomInset),
            children: [
              _InspectionCard(i: i),
              const SizedBox(height: 12),
              SdmCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (i.photoUrl != null) ...[
                      KpiThumb(i.photoUrl!, size: 72),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jarak dari outlet ${i.distanceMeters.round()} m',
                              style: const TextStyle(color: AppTheme.textSecondary)),
                          if (i.notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Catatan: ${i.notes}', style: const TextStyle(color: AppTheme.textPrimary)),
                          ],
                          if (i.followUp.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Tindak lanjut: ${i.followUp}', style: const TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (final g in order) ...[
                const SizedBox(height: 16),
                Text(inspectionGroupLabels[g] ?? g,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                SdmCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      for (final r in groups[g]!)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                r.passed ? Icons.check_circle_outline : Icons.cancel_outlined,
                                color: r.passed ? const Color(0xFF15803D) : AppTheme.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.itemName, style: const TextStyle(color: AppTheme.textPrimary)),
                                    if (r.note.isNotEmpty)
                                      Text(r.note, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              if (r.photoUrl != null) KpiThumb(r.photoUrl!, size: 44),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
