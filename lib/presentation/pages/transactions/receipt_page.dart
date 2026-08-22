import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/data/repositories/receipt_repository.dart';
import 'package:pos_mobile/presentation/providers/printer_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Halaman nota: menampilkan pratinjau struk dan tombol cetak ke printer thermal.
class ReceiptPage extends ConsumerWidget {
  final String invoiceNo;

  const ReceiptPage({super.key, required this.invoiceNo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(receiptProvider(invoiceNo));

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Nota'), centerTitle: true),
      body: receiptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat nota:\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(receiptProvider(invoiceNo)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (receipt) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _ReceiptPreview(receipt: receipt),
              ),
            ),
            _PrintBar(receipt: receipt),
          ],
        ),
      ),
    );
  }
}

class _PrintBar extends StatelessWidget {
  final Receipt receipt;
  const _PrintBar({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _openPrinterSheet(context, receipt),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Cetak Nota', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandBlue,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
    );
  }
}

void _openPrinterSheet(BuildContext context, Receipt receipt) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => PrinterPickerSheet(receipt: receipt),
  );
}

// Gaya angka monospace agar nominal sejajar rapi seperti struk asli.
const _moneyStyle = TextStyle(
  color: AppTheme.textPrimary,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  fontFamily: 'monospace',
  fontFeatures: [FontFeature.tabularFigures()],
);

class _ReceiptPreview extends StatelessWidget {
  final Receipt receipt;
  const _ReceiptPreview({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy • HH:mm');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== Header toko =====
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.brandBlue.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded, color: AppTheme.brandBlue, size: 22),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      receipt.store.name.isNotEmpty ? receipt.store.name : 'Toko',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const _DashedDivider(),
              // ===== Info transaksi =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    if (receipt.hasQueueNo)
                      _InfoLine(label: 'Antrian', value: '${receipt.queueNo}'),
                    _InfoLine(label: 'No. Invoice', value: receipt.invoiceNo),
                    if (receipt.createdAt != null)
                      _InfoLine(label: 'Tanggal', value: dateFmt.format(receipt.createdAt!.toLocal())),
                    _InfoLine(label: 'Kasir', value: receipt.cashierName),
                    if (receipt.customerName != null)
                      _InfoLine(label: 'Pelanggan', value: receipt.customerName!),
                    _InfoLine(label: 'Pembayaran', value: _paymentLabel(receipt.paymentMethod)),
                  ],
                ),
              ),
              const _DashedDivider(),
              // ===== Item =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'DETAIL PESANAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    ...receipt.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.qty} x ${formatRupiah(item.price)}',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(formatRupiah(item.lineTotal), style: _moneyStyle),
                                ],
                              ),
                              // Topping per item (gratis / berbayar)
                              ...item.toppings.map((t) => Padding(
                                    padding: const EdgeInsets.only(left: 10, top: 2),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '+ ${t.name} ×${t.qty}'
                                            '${t.isFree ? ' (gratis)' : ''}',
                                            style: TextStyle(
                                              color: t.isFree ? Colors.green.shade700 : AppTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        if (!t.isFree)
                                          Text(formatRupiah(t.lineTotal),
                                              style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 11,
                                                  fontFamily: 'monospace')),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const _DashedDivider(),
              // ===== Ringkasan =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    _AmountLine(label: 'Subtotal', value: receipt.subtotal),
                    ...receipt.promos.map((p) => _AmountLine(
                          label: p.name,
                          value: -p.discount,
                        )),
                    if (receipt.promos.isEmpty && receipt.promoDiscount > 0)
                      _AmountLine(label: 'Diskon Promo', value: -receipt.promoDiscount),
                    if (receipt.discount > 0) _AmountLine(label: 'Diskon', value: -receipt.discount),
                    if (receipt.tax > 0) _AmountLine(label: 'Pajak', value: receipt.tax),
                    const SizedBox(height: 10),
                    // Blok TOTAL menonjol
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.brandBlue.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            formatRupiah(receipt.total),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.brandBlue,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AmountLine(label: _paymentLabel(receipt.paymentMethod), value: receipt.paid),
                    _AmountLine(label: 'Kembalian', value: receipt.change),
                    if (receipt.paymentRef != null && receipt.paymentRef!.isNotEmpty)
                      _InfoLine(label: 'Ref', value: receipt.paymentRef!),
                  ],
                ),
              ),
              // ===== Estimasi siap =====
              // Hanya muncul bila BE mengirim estimasi; tanpa itu jangan
              // tampilkan apa pun (bukan berarti pesanan siap seketika).
              if (receipt.hasEstimate) ...[
                const _DashedDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 18, color: AppTheme.brandBlue),
                      const SizedBox(width: 8),
                      const Text(
                        'Estimasi siap',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('HH:mm').format(receipt.estimatedReadyAt!.toLocal()),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(±${receipt.estimatedPrepMinutes} menit)',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
              const _DashedDivider(),
              // ===== Footer =====
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  children: [
                    Text(
                      receipt.store.footerNote.isNotEmpty
                          ? receipt.store.footerNote
                          : 'Terima kasih atas kunjungan Anda',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (receipt.store.complaintNote.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        receipt.store.complaintNote,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _paymentLabel(String method) {
  switch (method.toLowerCase()) {
    case 'cash':
      return 'Tunai';
    case 'transfer':
    case 'bank_transfer':
      return 'Transfer';
    case 'qris':
      return 'QRIS';
    case 'debit':
      return 'Debit';
    case 'credit':
      return 'Kredit';
    case 'ewallet':
      return 'E-Wallet';
    default:
      return method.isEmpty ? 'Bayar' : method.toUpperCase();
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  final String label;
  final num value;
  const _AmountLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(formatRupiah(value), style: _moneyStyle),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 4.0;
          final count = (constraints.maxWidth / (dashWidth * 2)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => Container(
                width: dashWidth,
                height: 1.2,
                color: AppTheme.borderLight,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom sheet untuk memilih printer Bluetooth yang dipasangkan lalu mencetak.
class PrinterPickerSheet extends ConsumerStatefulWidget {
  final Receipt receipt;
  const PrinterPickerSheet({super.key, required this.receipt});

  @override
  ConsumerState<PrinterPickerSheet> createState() => _PrinterPickerSheetState();
}

class _PrinterPickerSheetState extends ConsumerState<PrinterPickerSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerProvider.notifier).loadDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printerProvider);

    // Tampilkan pesan/error sebagai snackbar non-blocking.
    ref.listen(printerProvider, (prev, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.error != null && next.error != prev?.error) {
        messenger.showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ));
      } else if (next.message != null && next.message != prev?.message) {
        messenger.showSnackBar(SnackBar(
          content: Text(next.message!),
          backgroundColor: AppTheme.brandBlue,
          behavior: SnackBarBehavior.floating,
        ));
        if (next.message == 'Nota berhasil dicetak.' && mounted) {
          Navigator.pop(context);
        }
      }
    });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pilih Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: state.isBusy ? null : () => ref.read(printerProvider.notifier).loadDevices(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Petunjuk singkat untuk kasir
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppTheme.brandBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Printer harus sudah dipasangkan (pair) lewat Pengaturan Bluetooth HP. '
                      'Pilih printer di bawah untuk mencetak. Jika belum muncul, tekan refresh (↻).',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
                icon: const Icon(Icons.bluetooth, size: 18),
                label: const Text('Buka Pengaturan Bluetooth'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.brandBlue,
                  side: const BorderSide(color: AppTheme.brandBlue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PrinterState state) {
    if (state.phase == PrinterPhase.scanning && state.devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Tidak ada printer terpasang.\nPasangkan printer di pengaturan Bluetooth lalu tekan refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: state.devices.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
      itemBuilder: (context, index) {
        final device = state.devices[index];
        final isConnected = state.connectedMac == device.macAdress;
        final busy = state.isBusy;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.print, color: isConnected ? AppTheme.brandBlue : AppTheme.textSecondary),
          title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(device.macAdress, style: const TextStyle(fontSize: 12)),
          trailing: busy && isConnected
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: busy
              ? null
              : () => ref.read(printerProvider.notifier).connectAndPrint(
                    mac: device.macAdress,
                    name: device.name,
                    receipt: widget.receipt,
                  ),
        );
      },
    );
  }
}
