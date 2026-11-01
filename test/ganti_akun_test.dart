import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/data/models/me_model.dart';
import 'package:pos_mobile/data/models/my_day_model.dart';
import 'package:pos_mobile/data/repositories/attendance_repository.dart';
import 'package:pos_mobile/data/repositories/auth_repository.dart';
import 'package:pos_mobile/data/services/secure_storage.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';
import 'package:pos_mobile/presentation/providers/dashboard_index_provider.dart';
import 'package:pos_mobile/presentation/providers/session_cache.dart';

// Revisi uji manual 31 Okt 2026: sesudah logout lalu login akun lain di HP yang
// sama, hari saya dan kunci absen akun sebelumnya masih tampil, karena cache
// hanya dibuang saat pindah cabang.

String _token(String email) {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 3)).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'exp': exp, 'sub': email, 'role': 'karyawan', 'roles': ['karyawan'], 'branch_id': 7})}.tandatangan';
}

/// Hari saya milik siapa pun yang sedang login menurut [who]. Dibuat baru
/// tiap kali provider-nya lahir ulang, seperti repository sungguhan.
class _Attendance implements AttendanceRepository {
  final String Function() who;
  final void Function()? onRead;
  _Attendance(this.who, {this.onRead});

  @override
  Future<MyDay> getMyDay() async {
    onRead?.call();
    return MyDay(date: who(), shifts: const [], attendances: const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Auth implements AuthRepository {
  @override
  Future<void> login(String email, String password, {required bool rememberMe}) async {
    await SecureStorage.saveRememberMe(rememberMe);
    await SecureStorage.saveTokens(accessToken: _token(email), refreshToken: 'r-$email');
  }

  // Tanpa jaringan: identitas dibaca dari token.
  @override
  Future<MeModel> getMe() async => throw 'tidak ada jaringan';

  @override
  Future<RefreshOutcome> tryRefreshToken() async => RefreshOutcome.refreshed;

  @override
  Future<void> logout() => SecureStorage.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('clearSessionCache', () {
    test('hari saya, daftar cabang, dan tab dibaca ulang', () async {
      var dayReads = 0;
      var branchReads = 0;
      final container = ProviderContainer(overrides: [
        attendanceRepositoryProvider.overrideWith((ref) {
          ref.watch(branchScopeProvider);
          return _Attendance(() => 'A', onRead: () => dayReads++);
        }),
        branchListProvider.overrideWith((ref) async {
          branchReads++;
          return const <BranchModel>[];
        }),
      ]);
      addTearDown(container.dispose);

      await container.read(myDayProvider.future);
      await container.read(branchListProvider.future);
      container.read(dashboardIndexProvider.notifier).state = 3;
      await container.read(myDayProvider.future);
      expect(dayReads, 1, reason: 'tanpa pembersihan, nilainya disajikan dari cache');

      clearSessionCache(container.invalidate, container.read(branchScopeProvider.notifier));

      await container.read(myDayProvider.future);
      await container.read(branchListProvider.future);
      expect(dayReads, 2);
      expect(branchReads, 2);
      expect(container.read(dashboardIndexProvider), 0);
    });
  });

  group('ganti akun di HP yang sama', () {
    late ProviderContainer container;
    late String current;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      current = '';
      container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(_Auth()),
        attendanceRepositoryProvider.overrideWith((ref) {
          ref.watch(branchScopeProvider);
          return _Attendance(() => current);
        }),
      ]);
      container.read(authProvider.notifier);
      await _settle();
    });

    tearDown(() => container.dispose());

    test('logout lalu login akun lain: hari saya milik akun baru', () async {
      final auth = container.read(authProvider.notifier);

      current = 'alamleader';
      await auth.login('alamleader@x', 'rahasia', rememberMe: true);
      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect((await container.read(myDayProvider.future)).date, 'alamleader');

      await auth.logout();
      current = 'akundemo';
      await auth.login('akundemo@x', 'rahasia', rememberMe: true);

      expect((await container.read(myDayProvider.future)).date, 'akundemo');
    });

    test('token hilang dari storage (logout paksa): cache ikut dibuang', () async {
      final auth = container.read(authProvider.notifier);

      current = 'alamleader';
      await auth.login('alamleader@x', 'rahasia', rememberMe: true);
      expect((await container.read(myDayProvider.future)).date, 'alamleader');

      current = 'akundemo';
      await SecureStorage.clear();
      await _settle();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect((await container.read(myDayProvider.future)).date, 'akundemo');
    });
  });
}
