import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/services/printer_prefs.dart';
import 'package:pos_mobile/data/repositories/receipt_repository.dart';
import 'package:pos_mobile/presentation/providers/printer_provider.dart';
import 'package:pos_mobile/presentation/pages/transactions/receipt_page.dart';

class TransactionSuccessPage extends ConsumerStatefulWidget {
  final ProductTransactionResponse response;

  const TransactionSuccessPage({super.key, required this.response});

  @override
  ConsumerState<TransactionSuccessPage> createState() => _TransactionSuccessPageState();
}

class _TransactionSuccessPageState extends ConsumerState<TransactionSuccessPage> {
  bool _hasDefaultPrinter = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAutoPrint());
  }

  Future<void> _initAutoPrint() async {
    final mac = await PrinterPrefs.getMac();
    final auto = await PrinterPrefs.getAutoPrint();
    if (!mounted) return;
    setState(() => _hasDefaultPrinter = mac != null && mac.isNotEmpty);
    if (_hasDefaultPrinter && auto) _print();
  }

  Future<void> _print() async {
    final mac = await PrinterPrefs.getMac();
    if (mac == null || mac.isEmpty) return;
    final name = await PrinterPrefs.getName() ?? 'Printer';
    if (!mounted) return;
    setState(() => _attempted = true);
    try {
      final receipt = await ref.read(receiptProvider(widget.response.invoiceNumber).future);
      await ref.read(printerProvider.notifier).connectAndPrint(mac: mac, name: name, receipt: receipt);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal memuat nota: $e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _openManualPrint() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptPage(invoiceNo: widget.response.invoiceNumber)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 100),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            "Transaksi Berhasil!",
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Pembayaran telah diterima dan pesanan Anda sedang diproses.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppTheme.bgLight,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: AppTheme.borderLight),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "NOMOR INVOICE",
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.response.invoiceNumber,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: AppTheme.brandBlue,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_hasDefaultPrinter && _attempted) ...[
                            const SizedBox(height: 20),
                            _printStatus(printer),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
              child: Column(
                children: [
                  if (_hasDefaultPrinter) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: printer.isBusy ? null : _print,
                        icon: const Icon(Icons.print_outlined, color: AppTheme.brandBlue),
                        label: Text(
                          printer.isBusy ? "Mencetak…" : "Cetak Ulang",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.brandBlue),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: const BorderSide(color: AppTheme.brandBlue, width: 1.6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _openManualPrint,
                      child: const Text("Pilih printer lain",
                          style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openManualPrint,
                        icon: const Icon(Icons.print_outlined, color: AppTheme.brandBlue),
                        label: const Text(
                          "Cetak Nota",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.brandBlue),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: const BorderSide(color: AppTheme.brandBlue, width: 1.6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Atur printer default di Pengaturan untuk cetak otomatis.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandBlue,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 8,
                        shadowColor: AppTheme.brandBlue.withOpacity(0.4),
                      ),
                      child: const Text(
                        "Selesai & Ke Beranda",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _printStatus(PrinterState printer) {
    Color color;
    IconData icon;
    String text;

    if (printer.phase == PrinterPhase.connecting) {
      color = AppTheme.brandBlue;
      icon = Icons.bluetooth_searching;
      text = "Menghubungkan ke printer…";
    } else if (printer.phase == PrinterPhase.printing) {
      color = AppTheme.brandBlue;
      icon = Icons.print;
      text = "Mencetak nota…";
    } else if (printer.error != null) {
      color = AppTheme.danger;
      icon = Icons.error_outline;
      text = printer.error!;
    } else if (printer.message != null) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
      text = printer.message!;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          if (printer.isBusy)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
