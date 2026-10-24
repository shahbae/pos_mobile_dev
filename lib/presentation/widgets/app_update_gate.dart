import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/services/app_identity.dart';
import 'package:pos_mobile/presentation/providers/app_update_provider.dart';
import 'package:pos_mobile/presentation/widgets/app_update_dialog.dart';

/// Membungkus halaman supaya pembaruan muncul tanpa dicari.
///
/// Dua macam pembaruan:
/// - **Wajib** (versi terpasang di bawah rilis wajib, 24 Okt 2026): dialog yang
///   tidak bisa ditutup, di halaman login maupun sesudah masuk. Diperiksa saat
///   halaman dibuka, saat aplikasi kembali ke depan, dan setiap server membalas
///   426 — server bisa lebih dulu tahu daripada pengecekan terakhir.
/// - **Biasa**: ditawarkan sekali, hanya bila [offerOptional] (sesudah masuk),
///   dan bisa ditutup.
///
/// Gagal memeriksa — termasuk saat HP offline — tidak menghalangi apa pun.
/// Outlet yang sedang offline tetap bisa berjualan; begitu tersambung lagi,
/// server yang menolak dan dialog wajibnya muncul.
class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;
  final bool offerOptional;

  const AppUpdateGate({
    super.key,
    required this.child,
    this.offerOptional = false,
  });

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _offered = false;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppIdentity.upgradeRequired.addListener(_onRejected);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  @override
  void dispose() {
    AppIdentity.upgradeRequired.removeListener(_onRejected);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _evaluate(refresh: true);
  }

  void _onRejected() => _evaluate(refresh: true, rejected: true);

  Future<void> _evaluate({bool refresh = false, bool rejected = false}) async {
    if (_showing) return;
    _showing = true;
    try {
      if (refresh) await ref.read(appUpdateProvider.notifier).check();
      final status = await ref.read(appUpdateProvider.future);
      final latest = status.latest;
      if (!mounted || latest == null) return;

      // 426 berarti wajib walau angka minimum yang baru dibaca belum berubah:
      // server menyimpan minimumnya ±30 detik.
      final mandatory = status.mustUpdate || (rejected && status.hasUpdate);
      if (!mandatory) {
        if (!widget.offerOptional || _offered || !status.hasUpdate) return;
        _offered = true;
      }
      await showAppUpdateDialog(context, latest, mandatory: mandatory);
    } catch (_) {
      // Pengecekan versi tidak pernah boleh menjadi alasan aplikasi gagal
      // dibuka. Kegagalannya sudah terlihat di kartu Versi Aplikasi.
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
