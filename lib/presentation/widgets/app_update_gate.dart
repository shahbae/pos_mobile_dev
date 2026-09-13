import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/providers/app_update_provider.dart';
import 'package:pos_mobile/presentation/widgets/app_update_dialog.dart';

/// Membungkus halaman utama supaya pembaruan ditawarkan sekali saat aplikasi
/// dibuka.
///
/// Sengaja tidak menghalangi apa pun: kalau pengecekannya gagal atau servernya
/// tidak terjangkau, aplikasi berjalan seperti biasa dan tawarannya bisa
/// dimunculkan sendiri lewat tab Pengaturan.
class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  bool _offered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerOnce());
  }

  Future<void> _offerOnce() async {
    if (_offered) return;
    _offered = true;

    try {
      final status = await ref.read(appUpdateProvider.future);
      if (!mounted || !status.hasUpdate) return;
      await showAppUpdateDialog(context, status.latest!);
    } catch (_) {
      // Pengecekan versi tidak pernah boleh menjadi alasan aplikasi gagal
      // dibuka. Kegagalannya sudah terlihat di kartu Versi Aplikasi.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
