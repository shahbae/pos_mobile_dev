import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Layar pembayaran QRIS dinamis: tampilkan QR, hitung mundur, dan polling
/// status tiap ~3 detik. Pop dengan `String invoiceNo` saat lunas; pop `null`
/// bila dibatalkan/kedaluwarsa (keranjang dibiarkan utuh untuk retry).
///
/// Mode `manual` (QR statis cabang, belum ada gateway): BE mengirim
/// `manual_confirm: true` dan kasir menekan "Pembayaran Diterima" setelah dana
/// terlihat masuk di aplikasi merchant. Polling tetap jalan supaya layar ikut
/// ter-update bila transaksi diselesaikan dari HP lain.
class QrisPaymentPage extends ConsumerStatefulWidget {
  final QrisCharge charge;

  const QrisPaymentPage({super.key, required this.charge});

  @override
  ConsumerState<QrisPaymentPage> createState() => _QrisPaymentPageState();
}

/// Aksen pengingat mode manual (amber) — tidak ada di AppTheme.
const _hintAmber = Color(0xFFB45309);

enum _View { waiting, failed }

class _QrisPaymentPageState extends ConsumerState<QrisPaymentPage> {
  Timer? _pollTimer;
  Timer? _tick;
  bool _checking = false;
  bool _closing = false; // cegah pop ganda
  _View _view = _View.waiting;
  String _failStatus = QrisStatusValue.expired;
  String? _failMessage; // pesan dari BE bila lebih spesifik dari status
  Duration _remaining = Duration.zero;

  /// Mode manual: kasir yang menyatakan dana sudah masuk. Bisa berubah jadi
  /// false di tengah jalan (mis. cabang ternyata dikonfirmasi gateway).
  late bool _manualConfirm = widget.charge.manualConfirm;
  bool _confirming = false;

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
    if (_checking || _closing || _confirming || !mounted) return;
    _checking = true;
    try {
      final st = await _repo.getQrisStatus(widget.charge.paymentRef);
      if (!mounted) return;
      // Mode cabang bisa berubah (mis. Midtrans di-ACC di tengah sesi).
      if (st.isPending && st.manualConfirm != _manualConfirm) {
        setState(() => _manualConfirm = st.manualConfirm);
      }
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

  void _showFailed(String status, {String? message}) {
    if (_closing || _view == _View.failed) return;
    _stopTimers();
    setState(() {
      _view = _View.failed;
      _failStatus = status;
      _failMessage = message;
    });
  }

  /// Tombol "Pembayaran Diterima" — hanya muncul di mode manual. Sekali ditekan
  /// tidak bisa dibatalkan (pembatalan setelah lunas harus lewat refund owner),
  /// jadi selalu minta konfirmasi dulu.
  Future<void> _onConfirmPressed() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dana sudah masuk?'),
        content: Text(
          'Pastikan dana ${formatRupiah(widget.charge.grossAmount)} sudah masuk '
          'di aplikasi merchant. Setelah dikonfirmasi, transaksi tidak bisa '
          'dibatalkan.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Belum')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, sudah masuk',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _doConfirm();
  }

  Future<void> _doConfirm() async {
    if (_confirming || _closing) return;
    setState(() => _confirming = true);
    try {
      final st = await _repo.confirmQris(widget.charge.paymentRef);
      if (!mounted) return;
      _handleStatus(st.status, st.invoiceNo);
    } on QrisConfirmException catch (e) {
      if (!mounted) return;
      switch (e.kind) {
        case QrisConfirmFailure.gatewayAuto:
          // Cabang ternyata sudah pakai gateway — sembunyikan tombol, lanjut polling.
          setState(() => _manualConfirm = false);
          _toast(e.message);
        case QrisConfirmFailure.expired:
          _showFailed(QrisStatusValue.expired);
        case QrisConfirmFailure.notPending:
          // Device lain kemungkinan sudah menyelesaikan — ambil status terbaru.
          _toast(e.message);
          await _poll();
        case QrisConfirmFailure.notFound:
          _showFailed(QrisStatusValue.cancelled, message: e.message);
        case QrisConfirmFailure.other:
          _toast(e.message, danger: true);
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Gagal mengonfirmasi: $e', danger: true);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _toast(String msg, {bool danger = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: danger ? AppTheme.danger : null,
      behavior: SnackBarBehavior.floating,
    ));
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
          if (_manualConfirm) ...[
            const SizedBox(height: 16),
            _manualHint(),
          ],
          const SizedBox(height: 20),
          _devPanel(),
          const SizedBox(height: 24),
          if (_manualConfirm) ...[
            FilledButton.icon(
              onPressed: _confirming ? null : _onConfirmPressed,
              icon: _confirming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_confirming ? 'Memproses…' : 'Pembayaran Diterima'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.brandGreenDark,
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _confirming ? null : _onCancelPressed,
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

  /// Pengingat kasir di mode manual: tidak ada gateway yang mencocokkan nominal,
  /// jadi dana harus dicek sendiri di aplikasi merchant sebelum menekan tombol.
  Widget _manualHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _hintAmber.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hintAmber.withOpacity(0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: _hintAmber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cek dulu di aplikasi merchant apakah dana sudah masuk, baru '
              'tekan "Pembayaran Diterima".',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label disalin'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }

  /// Panel bantu development: tampilkan qr_url & payment_ref + tombol copy
  /// supaya bisa dites tanpa buka console. (Aman ditinggal; hanya info.)
  Widget _devPanel() {
    final qrUrl = widget.charge.qrUrl;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DEV / Test',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          _copyField('Payment Ref', widget.charge.paymentRef),
          if (qrUrl != null && qrUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            _copyField('QR URL', qrUrl),
          ],
        ],
      ),
    );
  }

  Widget _copyField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy, size: 18, color: AppTheme.brandBlue),
          tooltip: 'Salin $label',
          onPressed: () => _copy(label, value),
        ),
      ],
    );
  }

  Widget _buildFailed() {
    final isCancelled = _failStatus == QrisStatusValue.cancelled;
    final title = isCancelled ? 'Pembayaran dibatalkan' : 'Pembayaran gagal';
    final subtitle = _failMessage ?? switch (_failStatus) {
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
