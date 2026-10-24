import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:pos_mobile/data/models/app_release_model.dart';
import 'package:pos_mobile/data/repositories/app_update_repository.dart';
import 'package:pos_mobile/data/services/app_identity.dart';
import 'package:pos_mobile/presentation/providers/app_update_provider.dart';
import 'package:pos_mobile/presentation/widgets/app_update_gate.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Wajib update (24 Okt 2026): versi di bawah rilis wajib tidak boleh
// menutup dialog pembaruannya, di halaman login maupun sesudah masuk.

AppReleaseInfo _release({int versionCode = 31, int minVersionCode = 0}) {
  return AppReleaseInfo(
    version: '1.0.13',
    versionCode: versionCode,
    fileName: 'esteh-candi-kasir-v1.0.13.apk',
    fileSize: 62243614,
    checksumSha256: 'abc123',
    releaseNotes: '',
    downloadUrl: 'https://api-dev.estehcandi.com/download/apk',
    pageUrl: 'https://api-dev.estehcandi.com/download',
    minVersionCode: minVersionCode,
  );
}

/// Repository yang jawabannya bisa diganti di tengah tes, seperti server yang
/// rilisnya baru saja ditandai wajib.
class _FakeRepository extends AppUpdateRepository {
  AppReleaseInfo? release;
  _FakeRepository(this.release) : super(client: Dio());

  @override
  Future<AppReleaseInfo?> fetchActive() async => release;
}

Widget _gated(AppUpdateRepository repo, {bool offerOptional = false}) {
  return ProviderScope(
    overrides: [appUpdateRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppUpdateGate(
        offerOptional: offerOptional,
        child: const Scaffold(body: Text('Halaman login')),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Terpasang: 1.0.12 (30).
    PackageInfo.setMockInitialValues(
      appName: 'Kasir Es Teh',
      packageName: 'com.example.pos_mobile.dev',
      version: '1.0.12',
      buildNumber: '30',
      buildSignature: '',
    );
  });

  group('model', () {
    test(
      'membaca min_version_code; tanpa field berarti tidak ada yang wajib',
      () {
        final withMin = AppReleaseInfo.fromJson({
          'version': '1.0.13',
          'version_code': 31,
          'min_version_code': 31,
        });
        final without = AppReleaseInfo.fromJson({
          'version': '1.0.13',
          'version_code': 31,
        });
        expect(withMin.minVersionCode, 31);
        expect(without.minVersionCode, 0);
      },
    );

    test('wajib hanya bila versi terpasang di bawah minimum', () {
      AppUpdateStatus status(int installed, int min) => AppUpdateStatus(
        installedVersion: '-',
        installedCode: installed,
        latest: _release(minVersionCode: min),
      );
      expect(status(30, 31).mustUpdate, isTrue);
      expect(status(31, 31).mustUpdate, isFalse);
      // Ada versi baru tapi tidak wajib: tawaran biasa.
      expect(status(30, 0).mustUpdate, isFalse);
      expect(status(30, 0).hasUpdate, isTrue);
    });

    test('setiap permintaan API membawa nama dan versi app', () {
      AppIdentity.versionCode = 30;
      expect(AppIdentity.headers, {
        'X-App-Name': 'kasir',
        'X-App-Version-Code': '30',
      });
    });
  });

  group('dialog wajib', () {
    testWidgets('muncul di halaman login dan tidak bisa ditutup', (
      tester,
    ) async {
      await tester.pumpWidget(
        _gated(_FakeRepository(_release(minVersionCode: 31))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wajib perbarui aplikasi'), findsOneWidget);
      expect(find.text('Nanti saja'), findsNothing);
      expect(find.text('Perbarui Sekarang'), findsOneWidget);

      // Ketuk di luar dialog.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Wajib perbarui aplikasi'), findsOneWidget);

      // Tombol kembali Android.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Wajib perbarui aplikasi'), findsOneWidget);
    });

    testWidgets('pembaruan biasa tidak muncul di halaman login', (
      tester,
    ) async {
      await tester.pumpWidget(_gated(_FakeRepository(_release())));
      await tester.pumpAndSettle();

      expect(find.text('Pembaruan tersedia'), findsNothing);
      expect(find.text('Halaman login'), findsOneWidget);
    });

    testWidgets('pembaruan biasa sesudah masuk tetap bisa "Nanti saja"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _gated(_FakeRepository(_release()), offerOptional: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pembaruan tersedia'), findsOneWidget);
      await tester.tap(find.text('Nanti saja'));
      await tester.pumpAndSettle();
      expect(find.text('Pembaruan tersedia'), findsNothing);
    });

    testWidgets('balasan 426 dari server memunculkan dialog wajib', (
      tester,
    ) async {
      // Saat halaman dibuka, rilisnya belum wajib.
      final repo = _FakeRepository(_release());
      await tester.pumpWidget(_gated(repo));
      await tester.pumpAndSettle();
      expect(find.text('Wajib perbarui aplikasi'), findsNothing);

      // Admin menandainya wajib; permintaan berikutnya ditolak server. Server
      // menyimpan minimumnya sebentar, jadi /app-version belum tentu ikut
      // berubah — 426-nya sendiri sudah cukup.
      AppIdentity.upgradeRequired.value++;
      await tester.pumpAndSettle();

      expect(find.text('Wajib perbarui aplikasi'), findsOneWidget);
      expect(find.text('Nanti saja'), findsNothing);
    });
  });
}
