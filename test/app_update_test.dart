import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:pos_mobile/data/models/app_release_model.dart';
import 'package:pos_mobile/data/repositories/app_update_repository.dart';
import 'package:pos_mobile/presentation/providers/app_update_provider.dart';
import 'package:pos_mobile/presentation/widgets/app_version_card.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Widget test di repo ini WAJIB memakai `AppTheme.lightTheme` — lihat catatan
// panjang di shipment_detail_test.dart. Kartu ini memasang tombol selebar
// layar, jadi persis kena setelan minimumSize yang dimaksud di sana.

AppReleaseInfo _release({
  String version = '1.0.1',
  int versionCode = 2,
  String notes = '',
}) {
  return AppReleaseInfo(
    version: version,
    versionCode: versionCode,
    fileName: 'esteh-candi-kasir-v$version.apk',
    fileSize: 62243614,
    checksumSha256: 'abc123',
    releaseNotes: notes,
    downloadUrl: 'https://api-dev.estehcandi.com/download/apk',
    pageUrl: 'https://api-dev.estehcandi.com/download',
  );
}

/// Mengganti panggilan jaringan tanpa menyentuh bentuk repository aslinya.
class _FakeRepository extends AppUpdateRepository {
  final AppReleaseInfo? release;
  final Object? failure;

  _FakeRepository({this.release, this.failure}) : super(client: Dio());

  @override
  Future<AppReleaseInfo?> fetchActive() async {
    if (failure != null) throw failure!;
    return release;
  }
}

Widget _card(AppUpdateRepository repo) {
  return ProviderScope(
    overrides: [appUpdateRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: AppVersionCard()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Esteh Candi DEV',
      packageName: 'com.example.pos_mobile.dev',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('AppReleaseInfo.fromJson', () {
    test('membaca payload /app-version apa adanya', () {
      final info = AppReleaseInfo.fromJson({
        'app': 'kasir',
        'version': '1.0.0',
        'version_code': 1,
        'file_name': 'esteh-candi-kasir-v1.0.0.apk',
        'file_size': 62243614,
        'checksum_sha256': '5F0DE687',
        'release_notes': '  perbaikan cetak  ',
        'download_url': 'https://api-dev.estehcandi.com/download/apk',
        'page_url': 'https://api-dev.estehcandi.com/download',
      });

      expect(info.versionCode, 1);
      expect(info.label, '1.0.0 (1)');
      expect(info.fileSizeLabel, '59.4 MB');
      expect(info.releaseNotes, 'perbaikan cetak');
      // Checksum dibandingkan dengan hasil sha256 yang selalu huruf kecil.
      expect(info.checksumSha256, '5f0de687');
    });

    test('release_notes null tidak membuat model gagal dibentuk', () {
      final info = AppReleaseInfo.fromJson({
        'version': '2',
        'version_code': 2,
        'release_notes': null,
      });
      expect(info.releaseNotes, isEmpty);
      expect(info.versionCode, 2);
    });
  });

  group('AppUpdateStatus.hasUpdate', () {
    test('membandingkan versionCode, bukan nama versi', () {
      // Sebagai string "1.10.0" berada SEBELUM "1.9.0". Perbandingan yang
      // benar hanya lewat angka versionCode.
      const status = AppUpdateStatus(
        installedVersion: '1.9.0',
        installedCode: 9,
        latest: null,
      );
      expect(status.hasUpdate, isFalse);

      final naik = AppUpdateStatus(
        installedVersion: '1.9.0',
        installedCode: 9,
        latest: _release(version: '1.10.0', versionCode: 10),
      );
      expect(naik.hasUpdate, isTrue);
    });

    test('versi server yang lebih tua tidak dianggap pembaruan', () {
      final status = AppUpdateStatus(
        installedVersion: '1.0.0',
        installedCode: 23,
        latest: _release(version: '1.0.0', versionCode: 1),
      );
      expect(status.hasUpdate, isFalse);
    });
  });

  group('AppVersionCard', () {
    testWidgets('versi sama: menawarkan pemeriksaan ulang, bukan pembaruan',
        (tester) async {
      await tester.pumpWidget(
        _card(_FakeRepository(release: _release(version: '1.0.0', versionCode: 1))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terpasang 1.0.0 (1)'), findsOneWidget);
      expect(find.text('Sudah memakai versi terbaru.'), findsOneWidget);
      expect(find.text('Periksa Pembaruan'), findsOneWidget);
      expect(find.text('Perbarui Sekarang'), findsNothing);
    });

    testWidgets('ada versi lebih baru: tombol berubah jadi Perbarui Sekarang',
        (tester) async {
      await tester.pumpWidget(_card(_FakeRepository(release: _release())));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tersedia versi 1.0.1 (2)'), findsOneWidget);
      expect(find.text('Perbarui Sekarang'), findsOneWidget);
    });

    testWidgets('server belum punya rilis aktif bukan keadaan error',
        (tester) async {
      await tester.pumpWidget(_card(_FakeRepository(release: null)));
      await tester.pumpAndSettle();

      expect(
        find.text('Belum ada rilis yang dipublikasikan di server.'),
        findsOneWidget,
      );
      expect(find.text('Periksa Pembaruan'), findsOneWidget);
    });

    testWidgets('pengecekan gagal: versi terpasang tetap terbaca',
        (tester) async {
      await tester.pumpWidget(
        _card(_FakeRepository(failure: 'Gagal memeriksa versi terbaru')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terpasang 1.0.0 (1)'), findsOneWidget);
      expect(find.text('Gagal memeriksa versi terbaru'), findsOneWidget);
    });
  });
}
