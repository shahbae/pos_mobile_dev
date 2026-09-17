import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pos_mobile/data/models/app_release_model.dart';
import 'package:pos_mobile/presentation/providers/app_update_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Menawarkan pembaruan ke pengguna: unduh, verifikasi, lalu serahkan ke
/// pemasang Android. Selalu bisa ditutup — pembaruan di sini bersifat anjuran,
/// dan kasir yang sedang melayani antrean tidak boleh terkunci olehnya.
Future<void> showAppUpdateDialog(
  BuildContext context,
  AppReleaseInfo release,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AppUpdateDialog(release: release),
  );
}

enum _Phase { idle, downloading, installing, failed }

class _AppUpdateDialog extends ConsumerStatefulWidget {
  final AppReleaseInfo release;

  const _AppUpdateDialog({required this.release});

  @override
  ConsumerState<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<_AppUpdateDialog> {
  _Phase _phase = _Phase.idle;
  int _received = 0;
  int _total = 0;
  String? _error;
  CancelToken? _cancel;

  bool get _busy => _phase == _Phase.downloading || _phase == _Phase.installing;

  double? get _progress {
    if (_total <= 0) return null;
    return (_received / _total).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final cancel = CancelToken();
    setState(() {
      _phase = _Phase.downloading;
      _error = null;
      _received = 0;
      _total = widget.release.fileSize;
      _cancel = cancel;
    });

    try {
      final updater = ref.read(appUpdaterProvider);
      final apk = await updater.download(
        widget.release,
        cancelToken: cancel,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );

      if (!mounted) return;
      setState(() => _phase = _Phase.installing);
      await updater.install(apk);

      // Layar pemasangan Android sudah di depan pengguna; dialog ini tidak
      // punya kabar lain untuk disampaikan. Apakah pemasangannya jadi atau
      // tidak, aplikasi ini tidak akan tahu — ia dimatikan saat APK-nya
      // ditimpa.
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (mounted) setState(() => _phase = _Phase.idle);
        return;
      }
      _fail('Unduhan gagal. Periksa koneksi lalu coba lagi.');
    } catch (e) {
      _fail(e.toString());
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  Future<void> _openInBrowser() async {
    final url = widget.release.pageUrl;
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String get _progressLabel {
    const mb = 1024 * 1024;
    final received = (_received / mb).toStringAsFixed(1);
    if (_total <= 0) return '$received MB terunduh';
    final total = (_total / mb).toStringAsFixed(1);
    final percent = ((_received / _total) * 100).clamp(0, 100).toStringAsFixed(0);
    return '$received MB dari $total MB · $percent%';
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;

    return PopScope(
      // Menutup dialog di tengah unduhan akan meninggalkan unduhan yang tidak
      // ada yang memantau. Tombol Batal yang membatalkannya, bukan tombol
      // kembali.
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: AppTheme.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.system_update_alt,
                color: AppTheme.brandBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Pembaruan tersedia',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Versi ${release.label} · ${release.fileSizeLabel}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (release.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Text(
                    release.releaseNotes,
                    style: AppTheme.body.copyWith(fontSize: 12),
                  ),
                ),
              ],
              if (_phase == _Phase.downloading) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: AppTheme.borderLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_progressLabel, style: AppTheme.body.copyWith(fontSize: 12)),
              ],
              if (_phase == _Phase.installing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Menyiapkan pemasangan…',
                        style: AppTheme.body.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.25)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kalau berulang, aplikasinya masih bisa diunduh lewat browser.',
                  style: AppTheme.body.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        actions: _actions(),
      ),
    );
  }

  List<Widget> _actions() {
    switch (_phase) {
      case _Phase.downloading:
        return [
          TextButton(
            onPressed: () => _cancel?.cancel(),
            child: const Text('Batal'),
          ),
        ];

      case _Phase.installing:
        return const [];

      case _Phase.failed:
        return [
          TextButton(
            onPressed: _openInBrowser,
            child: const Text('Buka di browser'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: _start,
            child: const Text('Coba lagi'),
          ),
        ];

      case _Phase.idle:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nanti saja'),
          ),
          FilledButton(
            onPressed: _start,
            child: const Text('Perbarui Sekarang'),
          ),
        ];
    }
  }
}
