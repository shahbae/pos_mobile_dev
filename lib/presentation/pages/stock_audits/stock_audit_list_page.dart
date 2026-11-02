import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_audit_provider.dart';
import 'package:pos_mobile/presentation/widgets/branch_switch_sheet.dart';
import 'package:pos_mobile/presentation/widgets/paged_list_view.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'stock_audit_detail_page.dart';
import 'stock_audit_form_page.dart';

class StockAuditListPage extends ConsumerWidget {
  const StockAuditListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canCreate = canCreateAudit(auth.role);

    // BE 2026-08-03 §4: role non-owner terkunci ke cabang di token dan wajib
    // punya konteks cabang. Tangkap lebih awal supaya tidak berujung 400.
    final needsBranch =
        auth.role?.toLowerCase() != 'owner' && auth.branchId == null;
    if (needsBranch) {
      return Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(title: const Text('Audit Stok'), centerTitle: true),
        body: const BranchRequiredView(reason: 'Audit stok dihitung per cabang.'),
      );
    }

    final audits = ref.watch(stockAuditListProvider);
    final auditsNotifier = ref.watch(stockAuditListProvider.notifier);
    final ownerLevel = isOwnerLevel(auth.held);

    Future<void> openForm(String type) async {
      final created = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockAuditFormPage(auditType: type)),
      );
      if (created == true) {
        ref.invalidate(stockAuditListProvider);
        ref.invalidate(auditPeriodsProvider);
      }
    }

    Future<void> openDetail(int id) async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => StockAuditDetailPage(auditId: id)));
      ref.invalidate(stockAuditListProvider);
      ref.invalidate(auditPeriodsProvider);
    }

    // Jenis berperiode yang sudah dibuat untuk periodenya dibuka, bukan dibuat
    // ulang (server membalas 409). Bulanan hanya owner & SPV.
    Future<void> pickType() async {
      final periods = ref.read(auditPeriodsProvider).valueOrNull;
      final types = [
        for (final t in AuditTypes.periodic)
          if ((t != AuditTypes.monthly || ownerLevel) && (periods?.of(t)?.listedCount ?? 1) > 0) t,
        AuditTypes.general,
      ];
      final chosen = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Jenis opname', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              for (final t in types)
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined, color: AppTheme.brandBlue),
                  title: Text('Opname ${auditTypeLabel(t)}'),
                  subtitle: Text(periods?.of(t)?.hasAudit == true
                      ? 'Sudah dibuat untuk ${periods!.of(t)!.periodKey} — buka'
                      : auditTypeHint(t)),
                  onTap: () => Navigator.pop(ctx, t),
                ),
            ],
          ),
        ),
      );
      if (chosen == null || !context.mounted) return;
      final existing = periods?.of(chosen);
      if (existing?.auditId != null) {
        await openDetail(existing!.auditId!);
      } else {
        await openForm(chosen);
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Audit Stok'), centerTitle: true),
      floatingActionButton: !canCreate
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.brandBlue,
              icon: const Icon(Icons.add),
              label: const Text('Audit Baru'),
              onPressed: pickType,
            ),
      body: PagedListView<StockAudit>(
        onRefresh: () async {
          ref.invalidate(auditPeriodsProvider);
          await auditsNotifier.refresh();
        },
        header: _PeriodCards(
          showMonthly: ownerLevel,
          canCreate: canCreate,
          onOpenForm: openForm,
          onOpenDetail: openDetail,
        ),
        state: audits,
        notifier: auditsNotifier,
        unit: 'audit',
        emptyText: 'Belum ada audit stok',
        empty: const Column(
          children: [
            SizedBox(height: 140),
            Icon(Icons.fact_check_outlined, size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Center(child: Text('Belum ada audit stok', style: TextStyle(color: AppTheme.textSecondary))),
          ],
        ),
        itemBuilder: (context, audit) => _AuditCard(audit: audit),
      ),
    );
  }
}

/// Harian, Mingguan, (Bulanan untuk owner & SPV) periode berjalan (Tahap 5).
/// Jenis yang daftarnya kosong tidak dipakai cabang ini, jadi tidak tampil.
class _PeriodCards extends ConsumerWidget {
  final bool showMonthly;
  final bool canCreate;
  final Future<void> Function(String type) onOpenForm;
  final Future<void> Function(int id) onOpenDetail;

  const _PeriodCards({
    required this.showMonthly,
    required this.canCreate,
    required this.onOpenForm,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(auditPeriodsProvider).valueOrNull;
    if (periods == null) return const SizedBox.shrink();
    final shown = [
      for (final p in periods.periods)
        if (p.listedCount > 0 && (p.auditType != AuditTypes.monthly || showMonthly)) p,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in shown) ...[
            _PeriodCard(
              period: p,
              onTap: p.hasAudit
                  ? () => onOpenDetail(p.auditId!)
                  : (canCreate ? () => onOpenForm(p.auditType) : null),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final AuditPeriod period;
  final VoidCallback? onTap;
  const _PeriodCard({required this.period, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = period;
    final (String label, Color color) = !p.hasAudit
        ? ('Belum dibuat', AppTheme.textSecondary)
        : p.reasonsMissing > 0
            ? ('Menunggu alasan', AppTheme.danger)
            : (p.auditStatus == 'approved' ? ('Disetujui', Colors.green) : ('Draft', Colors.orange));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.hasAudit ? AppTheme.borderLight : AppTheme.brandBlue.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Opname ${auditTypeLabel(p.auditType)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${p.periodKey} · ${p.listedCount} barang'
                    '${p.unfairCount > 0 ? ' · ${p.unfairCount} tidak wajar' : ''}',
                    style: TextStyle(fontSize: 12, color: p.unfairCount > 0 ? AppTheme.danger : AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Chip(label: label, color: color),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class _AuditCard extends StatelessWidget {
  final StockAudit audit;
  const _AuditCard({required this.audit});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockAuditDetailPage(auditId: audit.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Opname ${auditTypeLabel(audit.auditType)}'
                      '${audit.periodKey != null ? ' · ${audit.periodKey}' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                  if (audit.unfairCount > 0)
                    Text('${audit.unfairCount} barang tidak wajar',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.danger)),
                  const SizedBox(height: 4),
                  Text(
                    audit.notes?.isNotEmpty == true ? audit.notes! : 'Tanpa catatan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  if ((audit.countedAt ?? audit.createdAt) != null) ...[
                    const SizedBox(height: 2),
                    Text(
                        '#${audit.id} · ${_fmtDate((audit.countedAt ?? audit.createdAt)!)}'
                        '${audit.createdByName?.isNotEmpty == true ? ' · ${audit.createdByName}' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            StatusChip(status: audit.status, waitingReasons: audit.waitingReasons),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;

  /// Draf dengan barang tidak wajar yang belum beralasan (Tahap 5).
  final bool waitingReasons;
  const StatusChip({super.key, required this.status, this.waitingReasons = false});

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final isApproved = lower == 'approved';
    final color = isApproved ? Colors.green : (waitingReasons ? AppTheme.danger : Colors.orange);
    final label = isApproved
        ? 'Disetujui'
        : waitingReasons
            ? 'Menunggu alasan'
            : (lower == 'draft' ? 'Draft' : status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

String _fmtDate(String iso) {
  try {
    return DateFormat('dd MMM yyyy • HH:mm').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}
