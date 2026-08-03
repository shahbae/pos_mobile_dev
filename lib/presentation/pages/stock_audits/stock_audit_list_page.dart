import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_audit_provider.dart';
import 'package:pos_mobile/presentation/widgets/branch_switch_sheet.dart';
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
        body: const _BranchRequiredView(),
      );
    }

    final auditsAsync = ref.watch(stockAuditListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Audit Stok'), centerTitle: true),
      floatingActionButton: !canCreate
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.brandBlue,
              icon: const Icon(Icons.add),
              label: const Text('Audit Baru'),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StockAuditFormPage()),
                );
                if (created == true) ref.invalidate(stockAuditListProvider);
              },
            ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(stockAuditListProvider),
        child: auditsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('Gagal memuat audit:\n$e', textAlign: TextAlign.center)),
            ],
          ),
          data: (audits) {
            if (audits.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 140),
                  Icon(Icons.fact_check_outlined, size: 56, color: AppTheme.textSecondary),
                  SizedBox(height: 12),
                  Center(child: Text('Belum ada audit stok', style: TextStyle(color: AppTheme.textSecondary))),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: audits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _AuditCard(audit: audits[i]),
            );
          },
        ),
      ),
    );
  }
}

/// Ditampilkan saat role non-owner belum punya cabang aktif — audit stok
/// selalu terikat cabang, jadi menu ini tidak bisa dibuka tanpa itu.
class _BranchRequiredView extends StatelessWidget {
  const _BranchRequiredView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          const Text(
            'Pilih cabang dulu',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Audit stok dihitung per cabang. Pilih cabang aktif dulu '
            'sebelum membuka menu ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => showBranchSwitchSheet(context),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Pilih Cabang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
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
                  Text('Audit #${audit.id}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    audit.notes?.isNotEmpty == true ? audit.notes! : 'Tanpa catatan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  if (audit.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(_fmtDate(audit.createdAt!),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            StatusChip(status: audit.status),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final isApproved = lower == 'approved';
    final color = isApproved ? Colors.green : Colors.orange;
    final label = isApproved ? 'Disetujui' : (lower == 'draft' ? 'Draft' : status);
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
