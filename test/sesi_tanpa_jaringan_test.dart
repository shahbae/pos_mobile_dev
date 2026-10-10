import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/models/me_model.dart';
import 'package:pos_mobile/data/repositories/auth_repository.dart';
import 'package:pos_mobile/data/services/secure_storage.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';

// Login butuh server. Kalau aplikasi yang dibuka ulang saat listrik mati
// menendang kasir ke layar login, ia tidak bisa masuk lagi sampai jaringan
// kembali — tepat saat aplikasi paling dibutuhkan untuk jualan offline.

/// Access token yang sudah kedaluwarsa, dengan peran dan cabang di dalamnya.
String _expiredToken() {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'exp': exp, 'role': 'kasir', 'branch_id': 7})}.tandatangan';
}

class _Repo implements AuthRepository {
  final RefreshOutcome outcome;
  int refreshCalls = 0;
  _Repo(this.outcome);

  @override
  Future<RefreshOutcome> tryRefreshToken() async {
    refreshCalls++;
    return outcome;
  }

  @override
  Future<MeModel> getMe() async => throw 'tidak ada jaringan';

  @override
  Future<void> logout() => SecureStorage.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = <String, String>{};

  setUp(() {
    storage
      ..clear()
      ..addAll({'ACCESS_TOKEN': _expiredToken(), 'REFRESH_TOKEN': 'refresh-lama', 'REMEMBER_ME': 'true'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        switch (call.method) {
          case 'write':
            storage[args['key'] as String] = args['value'] as String;
            return null;
          case 'read':
            return storage[args['key'] as String];
          case 'delete':
            storage.remove(args['key'] as String);
            return null;
          case 'deleteAll':
            storage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  Future<AuthNotifier> buka(_Repo repo) async {
    final n = AuthNotifier(repo);
    addTearDown(n.dispose);
    for (var i = 0; i < 20 && n.state.status == AuthStatus.unknown; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return n;
  }

  test('token kedaluwarsa dan server tak terjangkau: tetap masuk dengan sesi tersimpan', () async {
    final repo = _Repo(RefreshOutcome.unreachable);

    final auth = await buka(repo);

    expect(repo.refreshCalls, 1);
    expect(auth.state.status, AuthStatus.authenticated);
    expect(auth.state.role, 'kasir');
    expect(auth.state.branchId, 7, reason: 'peran dan cabang dibaca dari token yang tersimpan');
    expect(storage['REFRESH_TOKEN'], 'refresh-lama', reason: 'token tidak boleh ikut terhapus');
    expect(storage.containsKey('ACCESS_TOKEN'), isTrue);
  });

  test('token kedaluwarsa dan server menolak: keluar seperti biasa', () async {
    final auth = await buka(_Repo(RefreshOutcome.rejected));

    expect(auth.state.status, AuthStatus.unauthenticated);
    expect(storage.containsKey('ACCESS_TOKEN'), isFalse);
  });

  test('token kedaluwarsa dan berhasil diperbarui: masuk', () async {
    final auth = await buka(_Repo(RefreshOutcome.refreshed));

    expect(auth.state.status, AuthStatus.authenticated);
    expect(auth.state.branchId, 7);
  });
}
