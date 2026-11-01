import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/services/push_service.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_detail_page.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/widgets/branch_switch_sheet.dart';

// Revisi uji manual Tahap 1–4 (31 Okt 2026), bagian app kasir:
// - Ganti Cabang hanya untuk owner & SPV (catatan 9);
// - kamera pengecekan foto di layar kunci (catatan 8).

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthState _auth(List<String> roles) =>
    AuthState(status: AuthStatus.authenticated, role: roles.first, roles: roles);

Widget _host(Widget child, List<String> roles) => ProviderScope(
      overrides: [authProvider.overrideWith((ref) => _FixedAuth(_auth(roles)))],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ganti Cabang hanya owner & SPV', () {
    test('siapa yang boleh memilih cabang', () {
      expect(canSwitchBranch({'owner'}), isTrue);
      expect(canSwitchBranch({'supervisor'}), isTrue);
      expect(canSwitchBranch({'leader', 'supervisor'}), isTrue);
      for (final r in ['leader', 'karyawan', 'produksi', 'kasir']) {
        expect(canSwitchBranch({r}), isFalse, reason: r);
      }
    });

    test('pesan tanpa cabang tidak lagi menyuruh membuka Ganti Cabang', () {
      expect(branchRequiredMessage({'karyawan'}), kNoOutletTodayMsg);
      expect(branchRequiredMessage({'leader'}), kNoOutletTodayMsg);
      expect(branchRequiredMessage({'owner'}), contains('Ganti Cabang'));
    });

    testWidgets('karyawan: tanpa tombol Pilih Cabang, diarahkan absen', (tester) async {
      await tester.pumpWidget(_host(const BranchRequiredView(reason: 'Audit stok dihitung per cabang.'), ['karyawan']));
      expect(find.text('Pilih Cabang'), findsNothing);
      expect(find.textContaining('Absen masuk dulu'), findsOneWidget);
    });

    testWidgets('SPV: tombol Pilih Cabang tetap ada', (tester) async {
      await tester.pumpWidget(_host(const BranchRequiredView(reason: 'Audit stok dihitung per cabang.'), ['supervisor']));
      expect(find.text('Pilih Cabang'), findsOneWidget);
    });
  });

  group('kamera dari layar kunci', () {
    const channel = MethodChannel('estehcandi/notif');
    final calls = <String>[];

    void mock({required bool locked, bool unlocks = true}) {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'isKeyguardLocked':
            return locked;
          case 'dismissKeyguard':
            return unlocks;
        }
        return null;
      });
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('HP tidak terkunci: kamera langsung dibuka, tanpa minta buka kunci', () async {
      mock(locked: false);
      expect(await PushService.ensureUnlockedForCamera(), isTrue);
      expect(calls, ['isKeyguardLocked']);
    });

    test('HP terkunci: minta buka kunci dulu', () async {
      mock(locked: true);
      expect(await PushService.ensureUnlockedForCamera(), isTrue);
      expect(calls, ['isKeyguardLocked', 'dismissKeyguard']);
    });

    test('batal membuka kunci: kamera tidak dibuka', () async {
      mock(locked: true, unlocks: false);
      expect(await PushService.ensureUnlockedForCamera(), isFalse);
    });

    test('kanal belum ada (APK lama): kamera tetap dicoba', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      expect(await PushService.ensureUnlockedForCamera(), isTrue);
    });

    test('galat kamera ditampilkan apa adanya, tidak lagi diam', () {
      final denied = PlatformException(code: 'camera_access_denied', message: 'denied');
      expect(isCameraPermissionError(denied), isTrue);
      expect(cameraErrorMessage(denied), contains('Izin kamera ditolak'));
      expect(cameraErrorMessage(PlatformException(code: 'no_available_camera')), contains('Tidak ada app kamera'));
      final other = PlatformException(code: 'already_active', message: 'Image picker is already active');
      expect(isCameraPermissionError(other), isFalse);
      expect(cameraErrorMessage(other), contains('already_active'));
      expect(cameraErrorMessage(other), contains('Image picker is already active'));
    });
  });
}
