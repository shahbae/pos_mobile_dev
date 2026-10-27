import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/core/utils/currency_input_formatter.dart';
import 'package:pos_mobile/data/models/payroll_model.dart';
import 'package:pos_mobile/presentation/pages/payroll/payroll_widgets.dart';
import 'package:pos_mobile/presentation/providers/payroll_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Pinjaman sendiri (Tahap 2 SDM): ajukan, lihat perjalanannya, batalkan
/// selama belum diperiksa finance. Diperiksa finance, disetujui owner, lalu
/// dicairkan lewat transfer, tunai dari finance, atau tunai dari laci outlet.
/// Dipotong dari gaji di slip periode tanggal cairnya.
class MyLoansPage extends ConsumerStatefulWidget {
  const MyLoansPage({super.key});

  @override
  ConsumerState<MyLoansPage> createState() => _MyLoansPageState();
}

class _MyLoansPageState extends ConsumerState<MyLoansPage> {
  bool _busy = false;

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
    ));
  }

  Future<void> _request() async {
    final input = await showModalBottomSheet<({int amount, String purpose})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LoanRequestSheet(),
    );
    if (input == null || !mounted) return;
    final yakin = await confirmAction(
      context,
      title: 'Ajukan pinjaman ${formatRupiah(input.amount)}?',
      message: 'Diperiksa finance lalu disetujui owner. Sesudah cair, pinjaman '
          'dipotong dari gaji bulan itu.',
      confirmLabel: 'Ajukan',
    );
    if (!yakin || !mounted) return;
    await _run(
      () => ref.read(payrollRepositoryProvider).requestLoan(amount: input.amount, purpose: input.purpose),
      'Pinjaman diajukan.',
    );
  }

  Future<void> _cancel(LoanModel loan) async {
    final yakin = await confirmAction(
      context,
      title: 'Batalkan pinjaman?',
      message: '${formatRupiah(loan.amount)} untuk ${loan.purpose}. Pengajuan ini tidak bisa dipakai lagi.',
      confirmLabel: 'Ya, batalkan',
      danger: true,
    );
    if (!yakin || !mounted) return;
    await _run(() => ref.read(payrollRepositoryProvider).cancelLoan(loan.id), 'Pinjaman dibatalkan.');
  }

  Future<void> _run(Future<Object?> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(myLoansProvider);
      _snack(done);
    } catch (e) {
      if (!mounted) return;
      // Status bisa sudah berubah (mis. finance baru saja memeriksanya).
      ref.invalidate(myLoansProvider);
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myLoansProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Pinjaman'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _request,
        icon: const Icon(Icons.add),
        label: const Text('Ajukan pinjaman'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(myLoansProvider),
            child: async.when(
              loading: SdmStateView.loading,
              error: (e, _) => SdmStateView(
                icon: Icons.error_outline,
                message: '$e',
                onRetry: () => ref.invalidate(myLoansProvider),
              ),
              data: (rows) => ListView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 96 + bottomInset),
                children: [
                  const SdmNote(
                    icon: Icons.info_outline,
                    text: 'Pinjaman diperiksa finance lalu disetujui owner. Sesudah cair, '
                        'dipotong dari gaji di slip bulan cairnya.',
                  ),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    const SdmEmpty(icon: Icons.payments_outlined, message: 'Belum pernah mengajukan pinjaman.'),
                  for (final l in rows) ...[
                    _LoanCard(loan: l, onCancel: _busy || !l.cancellable ? null : () => _cancel(l)),
                    const SizedBox(height: 10),
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

class _LoanCard extends StatelessWidget {
  final LoanModel loan;
  final VoidCallback? onCancel;
  const _LoanCard({required this.loan, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final info = <String>[
      'Diajukan ${payrollDateTime(l.requestedAt)}',
      if (l.status == 'awaiting_cash')
        'Ambil tunai di kasir ${l.disburseBranchName ?? 'outlet'}; kasir yang sedang buka shift menyerahkannya',
      if (l.status == 'disbursed') 'Cair ${payrollDateTime(l.disbursedAt)} · ${l.methodLabel}',
      if (l.deductPayday != null)
        l.payslipId != null
            ? 'Sudah dipotong di gaji ${paydayMonth(l.deductPayday)}'
            : 'Dipotong di gaji ${paydayMonth(l.deductPayday)}',
    ];
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(formatRupiah(l.amount),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ),
              SdmPill(l.statusLabel, color: loanStatusColor(l.status)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.purpose, style: const TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          for (final line in info)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(line, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            ),
          if (l.status == 'rejected' && (l.rejectReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Alasan ditolak: ${l.rejectReason}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.danger)),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                child: const Text('Batalkan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoanRequestSheet extends StatefulWidget {
  const _LoanRequestSheet();

  @override
  State<_LoanRequestSheet> createState() => _LoanRequestSheetState();
}

class _LoanRequestSheetState extends State<_LoanRequestSheet> {
  final _amount = TextEditingController();
  final _purpose = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _purpose.dispose();
    super.dispose();
  }

  int get _value => int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  bool get _ready => _value > 0 && _purpose.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ajukan pinjaman',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purpose,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Untuk keperluan apa?'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _ready
                ? () => Navigator.pop(context, (amount: _value, purpose: _purpose.text.trim()))
                : null,
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }
}
