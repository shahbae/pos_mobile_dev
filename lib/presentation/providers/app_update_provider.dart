import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:pos_mobile/data/models/app_release_model.dart';
import 'package:pos_mobile/data/repositories/app_update_repository.dart';
import 'package:pos_mobile/data/services/app_updater.dart';

/// Versi yang sedang terpasang, disandingkan dengan rilis aktif di server.
class AppUpdateStatus {
  /// versionName dari APK, mis. "1.0.0".
  final String installedVersion;

  /// versionCode dari APK. Inilah yang dibandingkan — angka setelah `+` di
  /// `pubspec.yaml`, dan harus sama dengan `version_code` saat APK diunggah.
  final int installedCode;

  /// `null` bila server belum punya rilis aktif atau pengecekannya gagal.
  final AppReleaseInfo? latest;

  /// Terisi bila pengecekan terakhir gagal. Versi terpasang tetap diisi.
  final String? error;

  const AppUpdateStatus({
    required this.installedVersion,
    required this.installedCode,
    this.latest,
    this.error,
  });

  bool get hasUpdate =>
      latest != null && latest!.versionCode > installedCode;

  String get installedLabel => '$installedVersion ($installedCode)';
}

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  return AppUpdateRepository();
});

final appUpdaterProvider = Provider<AppUpdater>((ref) => AppUpdater());

class AppUpdateNotifier extends AsyncNotifier<AppUpdateStatus> {
  @override
  Future<AppUpdateStatus> build() => _load();

  /// Dipanggil tombol "Periksa Pembaruan". Versi terpasang yang sudah terbaca
  /// dipertahankan selama pengecekan berjalan supaya kartunya tidak berkedip
  /// kosong.
  Future<void> check() async {
    state = const AsyncLoading<AppUpdateStatus>().copyWithPrevious(state);
    state = AsyncData(await _load());
  }

  Future<AppUpdateStatus> _load() async {
    final info = await PackageInfo.fromPlatform();
    final code = int.tryParse(info.buildNumber) ?? 0;

    try {
      final latest = await ref.read(appUpdateRepositoryProvider).fetchActive();
      return AppUpdateStatus(
        installedVersion: info.version,
        installedCode: code,
        latest: latest,
      );
    } catch (e) {
      // Gagal menghubungi server bukan alasan menyembunyikan versi terpasang:
      // pertanyaan "ini versi berapa?" justru sering muncul saat jaringan
      // outlet sedang bermasalah.
      return AppUpdateStatus(
        installedVersion: info.version,
        installedCode: code,
        error: e.toString(),
      );
    }
  }
}

final appUpdateProvider =
    AsyncNotifierProvider<AppUpdateNotifier, AppUpdateStatus>(
  AppUpdateNotifier.new,
);
