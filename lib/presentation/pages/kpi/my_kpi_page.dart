import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_dispute_page.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _month = DateFormat('MMMM yyyy', 'id_ID');
final _when = DateFormat('EEE d MMM, HH.mm', 'id_ID');

String kpiPeriodLabel(String period) {
  final d = DateTime.tryParse('$period-01');
  return d == null ? period : _month.format(d);
}

String _shiftPeriod(String period, int months) {
  final d = DateTime.tryParse('$period-01') ?? DateTime.now();
  return kpiPeriodOf(DateTime(d.year, d.month + months, 1));
}

/// Skor KPI sendiri (Tahap 6): skor berjalan, rincian pool, kejadian dengan
/// bukti, dan sanggahan 3 hari. Leader mendapat tab Tim (lihat saja, tidak
/// bisa menilai).
class MyKpiPage extends ConsumerStatefulWidget {
  /// Periode awal `YYYY-MM`; kosong = bulan berjalan.
  final String? period;
  const MyKpiPage({super.key, this.period});

  @override
  ConsumerState<MyKpiPage> createState() => _MyKpiPageState();
}

class _MyKpiPageState extends ConsumerState<MyKpiPage> {
  late final String _current = kpiPeriodOf(DateTime.now());
  late String _period = widget.period ?? _current;

  @override
  Widget build(BuildContext context) {
    final leader = canSeeTeamKpi(ref.watch(authProvider).held);
    final switcher = _PeriodSwitcher(
      period: _period,
      canNext: _period.compareTo(_current) < 0,
      onChange: (p) => setState(() => _period = p),
    );
    final mine = _MyScoresView(period: _period, header: switcher);
    if (!leader) {
      return Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(title: const Text('Skor KPI'), centerTitle: true),
        body: mine,
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: const Text('Skor KPI'),
          centerTitle: true,
          bottom: const TabBar(tabs: [Tab(text: 'Skor saya'), Tab(text: 'Tim')]),
        ),
        body: TabBarView(
          children: [
            mine,
            _TeamView(period: _period, header: switcher),
          ],
        ),
      ),
    );
  }
}

class _PeriodSwitcher extends StatelessWidget {
  final String period;
  final bool canNext;
  final ValueChanged<String> onChange;
  const _PeriodSwitcher({required this.period, required this.canNext, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Bulan sebelumnya',
          onPressed: () => onChange(_shiftPeriod(period, -1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            kpiPeriodLabel(period),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          onPressed: canNext ? () => onChange(_shiftPeriod(period, 1)) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _MyScoresView extends ConsumerWidget {
  final String period;
  final Widget header;
  const _MyScoresView({required this.period, required this.header});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myKpiProvider(period));
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myKpiProvider(period)),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottomInset),
        children: [
          header,
          const SizedBox(height: 8),
          ...async.when(
            loading: () => const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator()),
            ],
            error: (e, _) => [
              _Message(
                icon: e is KpiNotActive ? Icons.event_busy_outlined : Icons.error_outline,
                text: e is KpiNotActive ? 'KPI belum berlaku untuk ${kpiPeriodLabel(period)}.' : '$e',
                onRetry: e is KpiNotActive ? null : () => ref.invalidate(myKpiProvider(period)),
              ),
            ],
            data: (v) => v.scores.isEmpty
                ? const [
                    SdmEmpty(
                      icon: Icons.insights_outlined,
                      message: 'Belum ada skor bulan ini.\nSkor muncul untuk crew yang berjadwal, leader outlet, dan SPV.',
                    ),
                  ]
                : [
                    for (final s in v.scores) ...[
                      _ScoreSection(score: s, period: period),
                      const SizedBox(height: 20),
                    ],
                    if (v.inputCloseAt != null)
                      SdmNote(
                        icon: Icons.schedule,
                        text: 'Penilaian dan sanggahan ${kpiPeriodLabel(period)} ditutup '
                            '${_when.format(v.inputCloseAt!.toLocal().subtract(const Duration(minutes: 1)))}.',
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;
  const _Message({required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ],
      ),
    );
  }
}

class _ScoreSection extends StatelessWidget {
  final KpiScore score;
  final String period;
  const _ScoreSection({required this.score, required this.period});

  @override
  Widget build(BuildContext context) {
    final d = score.detail;
    final pools = d?.pools ?? const <KpiPoolResult>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KpiScoreHeadline(score: score),
        if (score.status == 'running') ...[
          const SizedBox(height: 8),
          const SdmNote(
            icon: Icons.info_outline,
            text: 'Skor masih berjalan dan bisa berubah sampai bulan ini ditutup.',
          ),
        ],
        if (score.module == 'SPV') ...[
          const SizedBox(height: 8),
          const SdmNote(
            icon: Icons.groups_outlined,
            text: 'Reminder, tiket, dan sidak dihitung dari kerjamu sendiri. Hasil outlet '
                '(omzet, selisih stok, laporan, biaya, opname, skor leader) sama untuk semua '
                'SPV yang memegang outlet yang sama; targetnya mengikuti jumlah outlet yang kamu pegang.',
          ),
        ],
        if (pools.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _Heading('Rincian'),
          const SizedBox(height: 8),
          SdmCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [for (final p in pools) _PoolTile(pool: p)]),
          ),
          if ((d?.penalty ?? 0) > 0) ...[
            const SizedBox(height: 8),
            SdmNote(
              icon: Icons.remove_circle_outline,
              warning: true,
              text: 'Pengurang langsung ${kpiNum(d!.penalty)} poin (di luar bobot).',
            ),
          ],
        ],
        const SizedBox(height: 16),
        _Heading('Kejadian (${score.events.length})'),
        const SizedBox(height: 8),
        if (score.events.isEmpty)
          const SdmCard(
            child: Text('Belum ada kejadian bulan ini.', style: TextStyle(color: AppTheme.textSecondary)),
          )
        else
          for (final e in score.events) ...[
            KpiEventCard(event: e, period: period),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

/// Kepala skor: modul, angka besar, predikat, status.
class KpiScoreHeadline extends StatelessWidget {
  final KpiScore score;
  const KpiScoreHeadline({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = kpiPredicateColor(score.predicate);
    return SdmCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KPI ${kpiModuleLabels[score.module] ?? score.module}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary),
                ),
                if (score.branchName.isNotEmpty)
                  Text(score.branchName, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (score.predicate.isNotEmpty) SdmPill(score.predicate, color: color),
                    SdmPill(kpiStatusLabels[score.status] ?? score.status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            kpiNum(score.score),
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: score.score == null ? AppTheme.textSecondary : color),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary));
}

class _PoolTile extends StatelessWidget {
  final KpiPoolResult pool;
  const _PoolTile({required this.pool});

  String get _value {
    if (pool.na) return 'N/A';
    if (pool.isDirect) {
      final total = pool.indicators.fold<double>(0, (a, i) => a + i.value);
      return total == 0 ? '0' : kpiPoints(-total.abs());
    }
    return '${kpiNum(pool.score)} / ${kpiNum(pool.weight)}';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text('${pool.code} ${pool.name}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        trailing: Text(_value,
            style: TextStyle(
                fontWeight: FontWeight.w800, color: pool.na ? AppTheme.textSecondary : AppTheme.textPrimary)),
        children: [
          for (final i in pool.indicators)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i.code} ${i.name}',
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                        // Pembilang & penyebut modul pusat (Tahap 7) supaya
                        // angkanya bisa dicek: "10 dari 12 minggu".
                        if (i.measure != null && i.measure!.denominator > 0)
                          Text(
                            kpiMeasureText(i.measure!),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_indicatorValue(pool, i),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _indicatorValue(KpiPoolResult pool, KpiIndicatorResult i) {
    if (i.na) return 'N/A';
    final events = i.events > 0 ? ' (${i.events}×)' : '';
    return switch (pool.method) {
      'deduct' || 'direct' => i.value == 0 ? '0$events' : '${kpiPoints(-i.value.abs())}$events',
      'achieve' => i.value == 0 ? '0$events' : '${kpiPoints(i.value.abs())}$events',
      _ => kpiNum(i.value),
    };
  }
}

/// Satu kejadian: indikator, poin, waktu, catatan, bukti, status, dan
/// sanggahan.
class KpiEventCard extends ConsumerWidget {
  final KpiEvent event;
  final String period;
  const KpiEventCard({super.key, required this.event, required this.period});

  Color get _pointsColor => event.points < 0 ? AppTheme.danger : const Color(0xFF15803D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event;
    final muted = !e.isCounted;
    final detail = [
      if (e.occurredAt != null) _when.format(e.occurredAt!.toLocal()),
      if (e.isOutlet) 'kejadian outlet',
      if (e.assessorName != null) 'oleh ${e.assessorName}',
    ].join(' · ');
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('${e.indicatorCode} ${e.indicatorName}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              ),
              const SizedBox(width: 8),
              Text(
                kpiPoints(e.points),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: muted ? AppTheme.textSecondary : _pointsColor,
                  decoration: e.status == 'REVERSED' ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (e.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(e.note, style: const TextStyle(color: AppTheme.textPrimary)),
          ],
          if (e.evidenceUrl != null) ...[
            const SizedBox(height: 8),
            KpiThumb(e.evidenceUrl!, size: 72),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (e.status != 'APPROVED')
                SdmPill(kpiEventStatusLabels[e.status] ?? e.status,
                    color: e.status == 'PENDING' ? const Color(0xFFD97706) : AppTheme.textSecondary),
              if (e.dispute != null)
                SdmPill(kpiDisputeLabels[e.dispute!.status] ?? e.dispute!.status, color: _disputeColor(e.dispute!.status)),
            ],
          ),
          if (e.status == 'REVERSED' && e.reverseReason != null) ...[
            const SizedBox(height: 6),
            Text('Dibatalkan: ${e.reverseReason}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (e.dispute?.decisionNote != null) ...[
            const SizedBox(height: 6),
            Text('Keputusan: ${e.dispute!.decisionNote}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (e.canDispute) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final d = await Navigator.push<KpiDispute>(
                    context,
                    MaterialPageRoute(builder: (_) => KpiDisputePage(event: e)),
                  );
                  if (d != null) ref.invalidate(myKpiProvider(period));
                },
                icon: const Icon(Icons.gavel_outlined, size: 18),
                label: Text(e.disputeUntil == null
                    ? 'Sanggah'
                    : 'Sanggah (sampai ${_when.format(e.disputeUntil!.toLocal())})'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _disputeColor(String status) => switch (status) {
    'open' => const Color(0xFFD97706),
    'accepted' => const Color(0xFF15803D),
    'rejected' => AppTheme.danger,
    _ => AppTheme.textSecondary,
  };
}

class _TeamView extends ConsumerWidget {
  final String period;
  final Widget header;
  const _TeamView({required this.period, required this.header});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kpiTeamProvider(period));
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(kpiTeamProvider(period)),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottomInset),
        children: [
          header,
          const SizedBox(height: 8),
          ...async.when(
            loading: () => const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator()),
            ],
            error: (e, _) => [
              _Message(
                icon: e is KpiNotActive ? Icons.event_busy_outlined : Icons.error_outline,
                text: e is KpiNotActive ? 'KPI belum berlaku untuk ${kpiPeriodLabel(period)}.' : '$e',
                onRetry: e is KpiNotActive ? null : () => ref.invalidate(kpiTeamProvider(period)),
              ),
            ],
            data: (t) => [
              if (t.branchName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(t.branchName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ),
              const SdmNote(
                icon: Icons.visibility_outlined,
                text: 'Hanya untuk dilihat. Penilaian crew dilakukan SPV atau owner.',
              ),
              const SizedBox(height: 16),
              if (t.leaders.isNotEmpty) ...[
                const _Heading('Leader'),
                const SizedBox(height: 8),
                SdmCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [for (final s in t.leaders) _TeamRow(score: s)]),
                ),
                const SizedBox(height: 16),
              ],
              const _Heading('Crew'),
              const SizedBox(height: 8),
              if (t.crew.isEmpty)
                const SdmCard(
                  child: Text('Belum ada skor crew bulan ini.', style: TextStyle(color: AppTheme.textSecondary)),
                )
              else
                SdmCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [for (final s in t.crew) _TeamRow(score: s)]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final KpiScore score;
  const _TeamRow({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = kpiPredicateColor(score.predicate);
    return ListTile(
      dense: true,
      title: Text(score.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      subtitle: score.predicate.isEmpty ? null : Text(score.predicate, style: TextStyle(color: color)),
      trailing: Text(
        kpiNum(score.score),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: score.score == null ? AppTheme.textSecondary : color),
      ),
    );
  }
}

/// Kartu ringkas di Profil: skor bulan berjalan, ketuk untuk rincian.
class MyKpiCard extends ConsumerWidget {
  const MyKpiCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canSeeOwnKpi(ref.watch(authProvider).held)) return const SizedBox.shrink();
    final period = kpiPeriodOf(DateTime.now());
    final async = ref.watch(myKpiProvider(period));
    final summary = async.when(
      loading: () => 'Memuat…',
      error: (e, _) => e is KpiNotActive ? 'KPI belum berlaku bulan ini' : 'Gagal memuat skor',
      data: (v) => v.scores.isEmpty
          ? 'Belum ada skor bulan ini'
          : v.scores
              .map((s) => '${kpiModuleLabels[s.module] ?? s.module} ${kpiNum(s.score)}'
                  '${s.predicate.isEmpty ? '' : ' · ${s.predicate}'}')
              .join('   '),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyKpiPage())),
      child: SdmCard(
        child: Row(
          children: [
            const Icon(Icons.insights_outlined, color: AppTheme.brandBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Skor KPI ${kpiPeriodLabel(period)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(summary, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
