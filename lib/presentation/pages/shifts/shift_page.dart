import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/core/utils/currency_input_formatter.dart';
import 'package:pos_mobile/data/models/shift_model.dart';
import 'package:pos_mobile/data/repositories/shift_repository.dart';
import 'package:pos_mobile/presentation/pages/shifts/shift_list_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/shift_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

class ShiftPage extends ConsumerWidget {
  const ShiftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Finance hanya boleh lihat riwayat (tidak buka/tutup, tidak akses shift aktif).
    final canOperate = canOperateShift(ref.watch(authProvider).role);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Shift Kasir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Shift',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShiftListPage()),
            ),
          ),
        ],
      ),
      body: !canOperate
          ? const _ReadOnlyShiftBody()
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(currentShiftProvider),
              child: ref.watch(currentShiftProvider).when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text('Gagal memuat shift:\n$e', textAlign: TextAlign.center)),
                        const SizedBox(height: 16),
                        Center(
                          child: OutlinedButton(
                            onPressed: () => ref.invalidate(currentShiftProvider),
                            child: const Text('Coba Lagi'),
                          ),
                        ),
                      ],
                    ),
                    data: (shift) => ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (shift == null)
                          _NoShiftCard(onOpen: () => _openShift(context, ref))
                        else
                          _ActiveShiftCard(shift: shift, onClose: () => _closeShift(context, ref, shift)),
                      ],
                    ),
                  ),
            ),
    );
  }

  Future<void> _openShift(BuildContext context, WidgetRef ref) async {
    // Kas awal kini otomatis dari master cabang; kasir tidak input/override.
    final defaultOpeningCash = ref.read(currentBranchProvider)?.defaultOpeningCash;
    final confirmed = await _confirmOpenShift(context, defaultOpeningCash);
    if (confirmed != true) return;

    await _runWithLoading(context, () async {
      await ref.read(shiftRepositoryProvider).open();
      ref.invalidate(currentShiftProvider);
    }, successMsg: 'Shift dibuka');
  }

  Future<void> _closeShift(BuildContext context, WidgetRef ref, ShiftModel shift) async {
    final amount = await _askAmount(
      context,
      title: 'Tutup Shift',
      label: 'Kas Akhir (uang fisik di laci)',
      confirmText: 'Tutup Shift',
    );
    if (amount == null) return;

    ShiftModel? result;
    await _runWithLoading(context, () async {
      result = await ref.read(shiftRepositoryProvider).closeCurrent(amount);
      ref.invalidate(currentShiftProvider);
    }, successMsg: 'Shift ditutup');

    if (result != null && context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => _ShiftSummaryDialog(shift: result!),
      );
    }
  }
}

/// Dialog konfirmasi buka shift. Kas awal read-only (dari master cabang).
Future<bool?> _confirmOpenShift(BuildContext context, num? defaultOpeningCash) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Buka Shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kas awal (modal laci) otomatis ditetapkan dari pengaturan cabang.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kas Awal',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(defaultOpeningCash ?? 0),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.brandBlue),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buka Shift'),
          ),
        ],
      );
    },
  );
}

/// Dialog input nominal uang.
Future<num?> _askAmount(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmText,
}) {
  final controller = TextEditingController();
  return showDialog<num>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.brandBlue),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
            onPressed: () {
              final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
              Navigator.pop(context, num.tryParse(digits) ?? 0);
            },
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
}

Future<void> _runWithLoading(
  BuildContext context,
  Future<void> Function() task, {
  required String successMsg,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    await task();
    if (context.mounted) Navigator.pop(context); // tutup loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(successMsg),
        backgroundColor: AppTheme.brandBlue,
        behavior: SnackBarBehavior.floating,
      ));
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal: $e'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

String paymentLabel(String method) {
  switch (method) {
    case 'cash':
      return 'Tunai';
    case 'transfer':
    case 'bank_transfer':
      return 'Transfer';
    case 'internal':
      return 'Internal';
    default:
      return method;
  }
}

/// Tampilan shift untuk role read-only (Finance): hanya riwayat.
class _ReadOnlyShiftBody extends StatelessWidget {
  const _ReadOnlyShiftBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: const Row(
            children: [
              Icon(Icons.visibility_outlined, color: AppTheme.textSecondary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Anda hanya dapat melihat riwayat shift. '
                  'Buka/tutup shift dilakukan oleh kasir.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShiftListPage()),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Lihat Riwayat Shift'),
          ),
        ),
      ],
    );
  }
}

class _NoShiftCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _NoShiftCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.lock_clock_outlined, color: Colors.orange, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Belum Ada Shift Aktif',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Buka shift terlebih dahulu sebelum mulai transaksi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Buka Shift', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveShiftCard extends StatelessWidget {
  final ShiftModel shift;
  final VoidCallback onClose;
  const _ActiveShiftCard({required this.shift, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.brandBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: AppTheme.brandBlue),
                        SizedBox(width: 6),
                        Text('SHIFT AKTIF',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.brandBlue)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text('#${shift.id}', style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              if (shift.openedAt != null)
                _row('Dibuka', dateFmt.format(shift.openedAt!.toLocal())),
              _row('Kas Awal', formatRupiah(shift.openingCash)),
              _row('Penjualan', formatRupiah(shift.totalSales)),
              _row('Penjualan Tunai', formatRupiah(shift.cashSalesResolved)),
              _row('Kas Seharusnya (estimasi)', formatRupiah(shift.expectedCashResolved)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Tutup Shift', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

/// Ringkasan saat shift ditutup (selisih kas + breakdown pembayaran).
class _ShiftSummaryDialog extends StatelessWidget {
  final ShiftModel shift;
  const _ShiftSummaryDialog({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ringkasan Shift',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _row('Kas Awal', formatRupiah(shift.openingCash)),
            _row('Penjualan', formatRupiah(shift.totalSales)),
            _row('Penjualan Tunai', formatRupiah(shift.cashSalesResolved)),
            const Divider(height: 24),
            _row('Kas Seharusnya', formatRupiah(shift.expectedCashResolved)),
            if (shift.closingCash != null) _row('Kas Akhir (Fisik)', formatRupiah(shift.closingCash!)),
            if (shift.differenceResolved != null) ...[
              const SizedBox(height: 4),
              Builder(builder: (_) {
                final diff = shift.differenceResolved!;
                final isMinus = diff < 0;
                final color = diff == 0
                    ? AppTheme.textSecondary
                    : (isMinus ? AppTheme.danger : AppTheme.brandBlue);
                final label = diff == 0
                    ? 'Sesuai'
                    : (isMinus ? 'Kurang' : 'Lebih');
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Selisih ($label)',
                        style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
                    Text('${isMinus ? '-' : ''}${formatRupiah(diff.abs())}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
                  ],
                );
              }),
            ],
            if (shift.payments.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Per Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...shift.payments.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${paymentLabel(p.method)} (${p.count}x)',
                            style: const TextStyle(color: AppTheme.textSecondary)),
                        Text(formatRupiah(p.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
