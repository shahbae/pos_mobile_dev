import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import 'package:pos_mobile/data/models/payroll_model.dart';
import 'package:pos_mobile/presentation/pages/payroll/payroll_widgets.dart';
import 'package:pos_mobile/presentation/providers/payroll_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Rincian satu slip: penghasilan, potongan beserta rinciannya, total
/// diterima, PDF, dan komplain. Slip yang sudah terbit tidak bisa diubah;
/// komplain yang diterima owner dibetulkan finance di slip berikutnya.
class PayslipDetailPage extends ConsumerStatefulWidget {
  final int payslipId;
  const PayslipDetailPage({super.key, required this.payslipId});

  @override
  ConsumerState<PayslipDetailPage> createState() => _PayslipDetailPageState();
}

class _PayslipDetailPageState extends ConsumerState<PayslipDetailPage> {
  bool _busy = false;

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
    ));
  }

  Future<void> _openPdf(PayslipView slip) async {
    setState(() => _busy = true);
    try {
      final path = await ref.read(payrollRepositoryProvider).downloadPayslipPdf(slip.id, slip.payday);
      final result = await OpenFilex.open(path, type: 'application/pdf');
      if (!mounted) return;
      if (result.type != ResultType.done) {
        _snack('Slip tersimpan, tapi tidak ada aplikasi pembuka PDF di HP ini.', error: true);
      }
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complain(PayslipView slip) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _ComplaintSheet(),
    );
    if (message == null || message.isEmpty || !mounted) return;
    final yakin = await confirmAction(
      context,
      title: 'Kirim komplain?',
      message: 'Owner akan membaca dan memutuskannya. Satu slip hanya bisa punya '
          'satu komplain yang menunggu.',
      confirmLabel: 'Kirim',
    );
    if (!yakin || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(payrollRepositoryProvider).complain(slip.id, message);
      if (!mounted) return;
      ref.invalidate(payslipProvider(slip.id));
      ref.invalidate(myPayslipsProvider);
      _snack('Komplain terkirim.');
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(payslipProvider(widget.payslipId));
    final slip = async.valueOrNull;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Slip Gaji'),
        centerTitle: true,
        actions: [
          if (slip != null)
            IconButton(
              tooltip: 'Unduh PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _busy ? null : () => _openPdf(slip),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(payslipProvider(widget.payslipId)),
            child: async.when(
              loading: SdmStateView.loading,
              error: (e, _) => SdmStateView(
                icon: Icons.error_outline,
                message: '$e',
                onRetry: () => ref.invalidate(payslipProvider(widget.payslipId)),
              ),
              data: (s) => ListView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
                children: [
                  _Header(slip: s),
                  const SizedBox(height: 16),
                  _LinesCard(title: 'Penghasilan', lines: s.earnings, total: s.totalEarnings),
                  const SizedBox(height: 12),
                  _LinesCard(title: 'Potongan', lines: s.deductions, total: s.totalDeductions),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.brandGreenDark,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Total diterima',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                        ),
                        Text(formatRupiah(s.netPay),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  if (s.carryOver > 0) ...[
                    const SizedBox(height: 12),
                    SdmNote(
                      icon: Icons.warning_amber_rounded,
                      warning: true,
                      text: 'Potongan bulan ini melebihi penghasilan. Sisa '
                          '${formatRupiah(s.carryOver)} dipotong di slip berikutnya.',
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Komplain',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  for (final c in s.complaints) ...[
                    _ComplaintCard(complaint: c),
                    const SizedBox(height: 8),
                  ],
                  if (!s.hasOpenComplaint) ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _complain(s),
                      icon: const Icon(Icons.report_outlined),
                      label: const Text('Ada yang salah? Ajukan komplain'),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Slip yang sudah terbit tidak diubah. Bila owner menerima komplainmu, '
                      'kekurangannya disusulkan di slip berikutnya.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(color: Colors.black26, child: Center(child: CircularProgressIndicator())),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final PayslipView slip;
  const _Header({required this.slip});

  @override
  Widget build(BuildContext context) {
    final s = slip;
    final account = s.bankAccount == null || s.bankAccount!.isEmpty
        ? 'Belum diisi'
        : [if (s.bankName != null && s.bankName!.isNotEmpty) s.bankName!, s.bankAccount!].join(' ');
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gaji ${paydayMonth(s.payday)}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text('Absensi ${periodRange(s.periodFrom, s.periodTo)}',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          const Divider(height: 24),
          _InfoRow('Nama', s.userName),
          if (s.position.isNotEmpty) _InfoRow('Jabatan', s.position),
          if (s.location.isNotEmpty) _InfoRow('Outlet', s.location),
          _InfoRow('Rekening', account),
          _InfoRow('Ditransfer', s.transferredAt == null ? 'Belum' : payrollDate(s.transferredAt)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _LinesCard extends StatelessWidget {
  final String title;
  final List<PayslipLine> lines;
  final num total;
  const _LinesCard({required this.title, required this.lines, required this.total});

  @override
  Widget build(BuildContext context) {
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Tidak ada.', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          for (final l in lines) PayslipLineTile(line: l),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('Total ${title.toLowerCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              ),
              Text(formatRupiah(total),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final PayslipComplaint complaint;
  const _ComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    final color = switch (c.status) {
      'accepted' => AppTheme.brandGreenDark,
      'rejected' => AppTheme.danger,
      _ => const Color(0xFF2563EB),
    };
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(payrollDateTime(c.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
              SdmPill(c.statusLabel, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.message, style: const TextStyle(color: AppTheme.textPrimary)),
          if (c.response != null && c.response!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.bgLight, borderRadius: BorderRadius.circular(10)),
              child: Text('Jawaban owner: ${c.response}',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComplaintSheet extends StatefulWidget {
  const _ComplaintSheet();

  @override
  State<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<_ComplaintSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Komplain slip',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Tulis apa yang salah, sebut tanggalnya bila ada. Mis. "Lembur 3 Nov belum masuk".',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Komplain'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _text.text.trim().isEmpty ? null : () => Navigator.pop(context, _text.text.trim()),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }
}
