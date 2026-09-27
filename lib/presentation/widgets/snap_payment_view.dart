import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:pos_mobile/theme/app_theme.dart';

/// Halaman Snap Midtrans (mode `midtrans_snap`) yang menampilkan QR QRIS.
///
/// Hanya menampilkan — status lunas tetap diambil dari polling BE, bukan dari
/// halaman ini. Karena itu WebView dikunci ke domain Midtrans: redirect ke
/// "finish URL" atau situs lain dicegah supaya layar kasir tidak pindah ke
/// halaman yang tidak ada hubungannya dengan pembayaran.
class SnapPaymentView extends StatefulWidget {
  final String url;

  const SnapPaymentView({super.key, required this.url});

  @override
  State<SnapPaymentView> createState() => _SnapPaymentViewState();
}

class _SnapPaymentViewState extends State<SnapPaymentView> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            // Gambar/skrip pendukung yang gagal tidak membuat QR hilang; hanya
            // kegagalan halaman utama yang perlu tombol muat ulang.
            if (err.isForMainFrame == false || !mounted) return;
            setState(() {
              _loading = false;
              _error = err.description;
            });
          },
          onNavigationRequest: (req) {
            if (!req.isMainFrame || isMidtransHost(req.url)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _reload() {
    setState(() {
      _error = null;
      _loading = true;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Halaman QR gagal dimuat',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Periksa koneksi internet lalu muat ulang. Transaksi tetap '
                'menunggu pembayaran.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Muat ulang'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

/// true bila [url] berada di domain Midtrans (app.midtrans.com,
/// app.sandbox.midtrans.com, dll.).
bool isMidtransHost(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host == 'midtrans.com' || host.endsWith('.midtrans.com');
}
