import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/stock_request_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_request_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'stock_request_form_page.dart';
import 'stock_request_list_page.dart' show StockRequestStatusChip, fmtRequestDate;

class StockRequestDetailPage extends ConsumerStatefulWidget {
  final int requestId;
  const StockRequestDetailPage({super.key, required this.requestId});

  @override
  ConsumerState<StockRequestDetailPage> createState() =>
      _StockRequestDetailPageState();
}

class _StockRequestDetailPageState
    extends ConsumerState<StockRequestDetailPage> {
  bool _busy = false;
  bool _changed = false;

  Future<void> _cancel(StockRequest req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan permintaan?'),
        content: const Text(
            'Permintaan ini akan ditarik dan gudang tidak akan memprosesnya. '
            'Tidak bisa dikembalikan — kalau masih butuh, ajukan yang baru.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tidak jadi')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Batalkan', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(stockRequestRepositoryProvider).cancelRequest(req.id);
      _changed = true;
      ref.invalidate(stockRequestDetailProvider(req.id));
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canEdit = canCreateStockRequest(auth.role);
    final async = ref.watch(stockRequestDetailProvider(widget.requestId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: Text('Permintaan #${widget.requestId}'),
          centerTitle: true,
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$e', textAlign: TextAlign.center),
            ),
          ),
          data: (req) => RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(stockRequestDetailProvider(widget.requestId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _header(req),
                if (req.isRejected && (req.rejectedReason?.isNotEmpty ?? false))
                  _rejectionNote(req.rejectedReason!),
                if (req.hasCut) _cutNotice(),
                const SizedBox(height: 16),
                const Text('Barang yang diminta',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                ...req.lines.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LineCard(line: l, decided: !req.isSubmitted),
                    )),
                if (canEdit && req.isEditable) ...[
                  const SizedBox(height: 12),
                  _actions(req),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(StockRequest req) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  req.branchName ?? 'Cabang #${req.branchId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppTheme.textPrimary),
                ),
              ),
              StockRequestStatusChip(status: req.status),
            ],
          ),
          const SizedBox(height: 8),
          if (req.requesterName != null)
            _kv('Diajukan oleh', req.requesterName!),
          if (req.createdAt != null)
            _kv('Tanggal', fmtRequestDate(req.createdAt!)),
          if (req.approvedAt != null)
            _kv('Diputuskan', fmtRequestDate(req.approvedAt!)),
          if (req.note.isNotEmpty) _kv('Catatan', req.note),
          if (req.isSubmitted) ...[
            const SizedBox(height: 8),
            const Text(
              'Gudang belum memutuskan. Selama masih menunggu, isinya masih '
              'bisa diubah.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _rejectionNote(String reason) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alasan gudang menolak',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.red.shade900)),
          const SizedBox(height: 4),
          Text(reason,
              style: TextStyle(fontSize: 13, color: Colors.red.shade900)),
        ],
      ),
    );
  }

  /// Disetujui tapi ada yang dipotong. Gampang terlewat kalau cuma dilihat dari
  /// label "Disetujui", padahal yang datang nanti lebih sedikit.
  Widget _cutNotice() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gudang menyetujui sebagian. Periksa jumlah yang di-acc di tiap '
              'barang di bawah.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(StockRequest req) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _cancel(req),
            icon: const Icon(Icons.close),
            label: const Text('Batalkan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final saved = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => StockRequestFormPage(existing: req)),
                    );
                    if (saved == true) {
                      _changed = true;
                      ref.invalidate(
                          stockRequestDetailProvider(widget.requestId));
                    }
                  },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Ubah'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  final StockRequestLine line;

  /// Sudah diputuskan gudang — baru sejak itu kolom "di-acc" punya arti.
  final bool decided;

  const _LineCard({required this.line, required this.decided});

  @override
  Widget build(BuildContext context) {
    final cut = decided && line.qtyApproved < line.qtyRequested;
    final refused = decided && line.qtyApproved <= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: refused ? Colors.red.shade200 : AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.displayName,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          _row('Diminta',
              '${_trimNum(line.packQty)} ${line.templateName} '
              '(${_trimNum(line.qtyRequested)} ${line.unit})'),
          if (decided)
            _row(
              refused ? 'Tidak dikirim' : 'Di-acc',
              refused
                  ? '—'
                  : '${_trimNum(line.packQtyApproved)} ${line.templateName} '
                      '(${_trimNum(line.qtyApproved)} ${line.unit})',
              highlight: cut,
              danger: refused,
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool highlight = false, bool danger = false}) {
    final color = danger
        ? Colors.red.shade700
        : (highlight ? Colors.orange.shade800 : AppTheme.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(v,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: highlight || danger
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: color)),
          ),
        ],
      ),
    );
  }
}

String _trimNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
