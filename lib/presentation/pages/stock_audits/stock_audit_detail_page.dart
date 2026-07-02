import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/stock_audit_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_audit_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';
import 'stock_audit_form_page.dart';
import 'stock_audit_list_page.dart' show StatusChip;

class StockAuditDetailPage extends ConsumerStatefulWidget {
  final int auditId;
  const StockAuditDetailPage({super.key, required this.auditId});

  @override
  ConsumerState<StockAuditDetailPage> createState() => _StockAuditDetailPageState();
}

class _StockAuditDetailPageState extends ConsumerState<StockAuditDetailPage> {
  bool _approving = false;
  bool _deleting = false;

  bool get _busy => _approving || _deleting;

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _edit(StockAudit audit) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StockAuditFormPage(audit: audit)),
    );
    if (saved == true) {
      ref.invalidate(stockAuditDetailProvider(widget.auditId));
      ref.invalidate(stockAuditListProvider);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Draft'),
        content: const Text('Hapus draft audit ini beserta itemnya? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(stockAuditRepositoryProvider).deleteAudit(widget.auditId);
      ref.invalidate(stockAuditListProvider);
      if (mounted) {
        _snack('Draft audit dihapus', Colors.green);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        _snack('$e', AppTheme.danger);
      }
    }
  }

  Future<void> _approve() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setujui Audit'),
        content: const Text('Setujui audit ini? Status akan berubah menjadi "Disetujui".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Setujui')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _approving = true);
    try {
      await ref.read(stockAuditRepositoryProvider).approveAudit(widget.auditId);
      ref.invalidate(stockAuditDetailProvider(widget.auditId));
      ref.invalidate(stockAuditListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Audit disetujui'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(stockAuditDetailProvider(widget.auditId));
    final audit = auditAsync.valueOrNull;
    final canManage =
        audit != null && audit.isDraft && canCreateAudit(ref.watch(authProvider).role);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text('Audit #${widget.auditId}'),
        centerTitle: true,
        actions: canManage
            ? [
                IconButton(
                  tooltip: 'Edit draft',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _busy ? null : () => _edit(audit),
                ),
                IconButton(
                  tooltip: 'Hapus draft',
                  icon: _deleting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_outline),
                  onPressed: _busy ? null : _delete,
                ),
              ]
            : null,
      ),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (audit) => _content(audit),
      ),
    );
  }

  Widget _content(StockAudit audit) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _box(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status', style: TextStyle(color: AppTheme.textSecondary)),
                        StatusChip(status: audit.status),
                      ],
                    ),
                    const Divider(height: 20, color: AppTheme.borderLight),
                    _row('Catatan', audit.notes?.isNotEmpty == true ? audit.notes! : '-'),
                    if (audit.createdAt != null) _row('Dibuat', _fmt(audit.createdAt!)),
                    if (audit.approvedAt != null) _row('Disetujui', _fmt(audit.approvedAt!)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text('HASIL HITUNG',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 1)),
              ),
              Container(
                decoration: _box(),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('Item', style: _th)),
                          Expanded(flex: 2, child: Text('Sistem', style: _th, textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('Fisik', style: _th, textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('Selisih', style: _th, textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderLight),
                    ...audit.items.map(_itemRow),
                  ],
                ),
              ),
              _lossSummary(audit),
            ],
          ),
        ),
        if (audit.isDraft && canApproveAudit(ref.watch(authProvider).role))
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _approve,
                  icon: _approving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_approving ? 'Memproses…' : 'Setujui Audit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _itemRow(StockAuditItem it) {
    final diffColor = it.diff == 0
        ? AppTheme.textSecondary
        : (it.diff < 0 ? AppTheme.danger : Colors.green);
    final diffText = it.diff > 0 ? '+${_fmtQty(it.diff)}' : _fmtQty(it.diff);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (it.typeLabel != null)
                  Text(it.typeLabel!, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                if (it.returnedQty > 0)
                  Text('Dikembalikan ${_fmtQty(it.returnedQty)}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                if (it.incomingToday > 0)
                  Text('Masuk hari ini ${_fmtQty(it.incomingToday)}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.brandBlue)),
                if (it.lossValue > 0)
                  Text('Rugi ${formatRupiah(it.lossValue)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.danger)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(_fmtQty(it.systemQty), textAlign: TextAlign.right, style: _td)),
          Expanded(flex: 2, child: Text(_fmtQty(it.physicalQty), textAlign: TextAlign.right, style: _td)),
          Expanded(
            flex: 2,
            child: Text(diffText,
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: diffColor)),
          ),
        ],
      ),
    );
  }

  /// Total estimasi kerugian dari semua item yang stoknya kurang.
  Widget _lossSummary(StockAudit audit) {
    final totalLoss = audit.items.fold<double>(0, (s, it) => s + it.lossValue);
    if (totalLoss <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.danger.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Estimasi Kerugian',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.danger)),
            Text(formatRupiah(totalLoss),
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.danger, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  String _fmtQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );

  BoxDecoration _box() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      );

  static const _th = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecondary);
  static const _td = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary);

  String _fmt(String iso) {
    try {
      return DateFormat('dd MMM yyyy • HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}
