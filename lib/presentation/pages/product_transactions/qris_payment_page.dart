import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Layar pembayaran QRIS dinamis: tampilkan QR, hitung mundur, dan polling
/// status tiap ~3 detik. Pop dengan `String invoiceNo` saat lunas; pop `null`
/// bila dibatalkan/kedaluwarsa (keranjang dibiarkan utuh untuk retry).
class QrisPaymentPage extends ConsumerStatefulWidget {
  final QrisCharge charge;

  const QrisPaymentPage({super.key, required this.charge});

  @override
  ConsumerState<QrisPaymentPage> createState() => _QrisPaymentPageState();
}

enum _View { waiting, failed }

class _QrisPaymentPageState extends ConsumerState<QrisPaymentPage> {
  Timer? _pollTimer;
  Timer? _tick;
  bool _checking = false;
  bool _closing = false; // cegah pop ganda
  _View _view = _View.waiting;
  String _failStatus = QrisStatusValue.expired;
  Duration _remaining = Duration.zero;

  ProductTransactionRepository get _repo =>
      ref.read(productTransactionRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _recomputeRemaining();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _recomputeRemaining() {
    final exp = widget.charge.expiresAt;
    _remaining = exp == null ? Duration.zero : exp.difference(DateTime.now());
    if (_remaining.isNegative) _remaining = Duration.zero;
  }

  void _onTick() {
    if (!mounted) return;
    setState(_recomputeRemaining);
    if (widget.charge.expiresAt != null && _remaining == Duration.zero) {
      // Waktu habis — hentikan polling & tampilkan gagal (BE juga menandai expired).
      _showFailed(QrisStatusValue.expired);
    }
  }

  Future<void> _poll() async {
    if (_checking || _closing || !mounted) return;
    _checking = true;
    try {
      final st = await _repo.getQrisStatus(widget.charge.paymentRef);
      if (!mounted) return;
      _handleStatus(st.status, st.invoiceNo);
    } catch (_) {
      // Abaikan error jaringan sesaat; polling berikutnya coba lagi.
    } finally {
      _checking = false;
    }
  }

  void _handleStatus(String status, String? invoiceNo) {
    switch (status) {
      case QrisStatusValue.pending:
        return; // lanjut menunggu
      case QrisStatusValue.paid:
        _finishPaid(invoiceNo);
        break;
      default: // expired | cancelled | denied | refunded
        _showFailed(status);
    }
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _tick?.cancel();
  }

  void _finishPaid(String? invoiceNo) {
    if (_closing) return;
    _closing = true;
    _stopTimers();
    Navigator.of(context).pop(invoiceNo ?? '');
  }

  void _showFailed(String status) {
    if (_closing || _view == _View.failed) return;
    _stopTimers();
    setState(() {
      _view = _View.failed;
      _failStatus = status;
    });
  }

  Future<void> _onCancelPressed() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pembayaran?'),
        content: const Text(
            'QR akan dibatalkan dan pesanan tidak diproses. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tidak')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, batalkan',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _doCancel();
  }

  Future<void> _doCancel() async {
    _stopTimers();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      // Aman terhadap race: BE bisa mengembalikan `paid` bila pelanggan keburu bayar.
      final status = await _repo.cancelQris(widget.charge.paymentRef);
      if (!mounted) return;
      Navigator.of(context).pop(); // tutup loading
      if (status == QrisStatusValue.paid) {
        // Konfirmasi sekali lagi untuk ambil invoice, lalu perlakukan sebagai lunas.
        final st = await _repo.getQrisStatus(widget.charge.paymentRef);
        if (!mounted) return;
        _finishPaid(st.invoiceNo);
      } else {
        _showFailed(QrisStatusValue.cancelled);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // tutup loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal membatalkan: $e'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ));
      // Lanjutkan polling supaya status tetap terpantau.
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    }
  }

  String _fmtCountdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _view == _View.failed || _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _view == _View.waiting) _onCancelPressed();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Pembayaran QRIS')),
        body: SafeArea(
          child: _view == _View.failed ? _buildFailed() : _buildWaiting(),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    final hasExpiry = widget.charge.expiresAt != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Scan untuk membayar',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(formatRupiah(widget.charge.grossAmount),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.brandBlue)),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: QrImageView(
                data: widget.charge.qrString,
                version: QrVersions.auto,
                size: 240,
                gapless: false,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (hasExpiry)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 18, color: AppTheme.brandGreenDark),
                  const SizedBox(width: 8),
                  Text('Berlaku ${_fmtCountdown(_remaining)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandGreenDark)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Menunggu pembayaran…',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _onCancelPressed,
            icon: const Icon(Icons.close, color: AppTheme.danger),
            label: const Text('Batalkan',
                style: TextStyle(color: AppTheme.danger)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    final isCancelled = _failStatus == QrisStatusValue.cancelled;
    final title = isCancelled ? 'Pembayaran dibatalkan' : 'Pembayaran gagal';
    final subtitle = switch (_failStatus) {
      QrisStatusValue.expired => 'QR sudah kedaluwarsa. Silakan ulangi pembayaran.',
      QrisStatusValue.cancelled => 'Transaksi dibatalkan. Keranjang masih tersimpan.',
      QrisStatusValue.denied => 'Pembayaran ditolak. Silakan coba lagi.',
      _ => 'Pembayaran tidak selesai. Silakan coba lagi.',
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isCancelled ? Icons.cancel_outlined : Icons.error_outline,
              size: 72, color: AppTheme.danger),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Kembali'),
            ),
          ),
        ],
      ),
    );
  }
}
