import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/api_provider.dart';
import '../../data/services/secure_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final bool loading;
  final String? error;

  const AuthState({required this.status, this.loading = false, this.error});

  AuthState copyWith({AuthStatus? status, bool? loading, String? error}) {
    return AuthState(
      status: status ?? this.status,
      loading: loading ?? this.loading,
      error: error,
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

  Future<void> _init() async {
    try {
      final hasToken = await SecureStorage.hasTokens();

      if (!hasToken) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
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

      // Success
      state = state.copyWith(status: AuthStatus.authenticated);
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

      state = state.copyWith(status: AuthStatus.authenticated, loading: false);
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
    await repo.logout();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}
