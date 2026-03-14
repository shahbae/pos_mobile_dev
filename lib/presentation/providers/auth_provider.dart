import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:pos_mobile/data/repositories/auth_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/data/services/secure_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

const _noChange = Object();

class AuthState {
  final AuthStatus status;
  final bool loading;
  final String? error;
  final String? role;

  const AuthState({
    required this.status,
    this.loading = false,
    this.error,
    this.role,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? loading,
    Object? error = _noChange,
    Object? role = _noChange,
  }) {
    return AuthState(
      status: status ?? this.status,
      loading: loading ?? this.loading,
      error: error == _noChange ? this.error : error as String?,
      role: role == _noChange ? this.role : role as String?,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiProvider);
  return AuthRepository(api);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository repo;

  AuthNotifier(this.repo) : super(const AuthState(status: AuthStatus.unknown)) {
    _init();
  }

  String? _extractRoleFromToken(String token) {
    try {
      final claims = JwtDecoder.decode(token);
      final raw =
          claims['role'] ??
          claims['user_role'] ??
          claims['userRole'] ??
          claims['roles'];
      if (raw is String) return raw.toLowerCase();
      if (raw is List && raw.isNotEmpty) {
        final first = raw.first;
        if (first is String) return first.toLowerCase();
      }
      if (raw is Map) {
        final name = raw['name'];
        if (name is String) return name.toLowerCase();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _init() async {
    try {
      final hasToken = await SecureStorage.hasTokens();

      if (!hasToken) {
        state = state.copyWith(status: AuthStatus.unauthenticated, role: null);
        return;
      }

      final accessToken = await SecureStorage.getAccessToken();

      // Token hilang / corrupted
      if (accessToken == null) {
        await logout();
        return;
      }

      // Jika token expired → refresh
      if (JwtDecoder.isExpired(accessToken)) {
        final ok = await repo.tryRefreshToken();

        if (!ok) {
          await logout();
          return;
        }
      }

      final latestToken = await SecureStorage.getAccessToken();
      if (latestToken == null) {
        await logout();
        return;
      }
      final role = _extractRoleFromToken(latestToken);

      // Success
      state = state.copyWith(status: AuthStatus.authenticated, role: role);
    } catch (e) {
      // Fail-safe → jangan bikin app stuck
      await logout();
    }
  }

  /// ---------------------------------------------------
  /// LOGIN
  /// ---------------------------------------------------
  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);

    try {
      await repo.login(email, password);

      final accessToken = await SecureStorage.getAccessToken();
      final role = accessToken == null
          ? null
          : _extractRoleFromToken(accessToken);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        loading: false,
        role: role,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(), // <-- pesan API diteruskan ke UI
      );
    }
  }

  /// ---------------------------------------------------
  /// LOGOUT
  /// ---------------------------------------------------
  Future<void> logout() async {
    try {
      await repo.logout();
    } finally {
      state = state.copyWith(status: AuthStatus.unauthenticated, role: null);
    }
  }
}
