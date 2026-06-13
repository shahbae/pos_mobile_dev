import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/repositories/auth_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/data/services/secure_storage.dart';

const _accessDeniedMsg =
    'Akses ditolak. Role Anda tidak diizinkan menggunakan aplikasi ini.';

enum AuthStatus { unknown, authenticated, unauthenticated }

const _noChange = Object();

class AuthState {
  final AuthStatus status;
  final bool loading;
  final String? error;
  final String? role;
  final int? branchId;

  const AuthState({
    required this.status,
    this.loading = false,
    this.error,
    this.role,
    this.branchId,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? loading,
    Object? error = _noChange,
    Object? role = _noChange,
    Object? branchId = _noChange,
  }) {
    return AuthState(
      status: status ?? this.status,
      loading: loading ?? this.loading,
      error: error == _noChange ? this.error : error as String?,
      role: role == _noChange ? this.role : role as String?,
      branchId: branchId == _noChange ? this.branchId : branchId as int?,
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
  late final StreamSubscription<void> _storageSub;

  AuthNotifier(this.repo) : super(const AuthState(status: AuthStatus.unknown)) {
    _storageSub = SecureStorage.changes.listen((_) async {
      final hasAccess = await SecureStorage.getAccessToken() != null;
      if (!hasAccess && state.status != AuthStatus.unauthenticated) {
        state = state.copyWith(status: AuthStatus.unauthenticated, role: null);
      }
    });
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

  int? _extractBranchIdFromToken(String token) {
    try {
      final claims = JwtDecoder.decode(token);
      final raw = claims['branch_id'] ?? claims['branchId'];
      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> reloadFromToken() async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) return;
    final role = _extractRoleFromToken(token);
    final branchId = _extractBranchIdFromToken(token);
    state = state.copyWith(role: role, branchId: branchId);
  }

  Future<void> _init() async {
    try {
      final hasToken = await SecureStorage.hasTokens();

      if (!hasToken) {
        if (kDebugMode) {
          debugPrint('Auth init | no access token | unauthenticated');
        }
        state = state.copyWith(status: AuthStatus.unauthenticated, role: null);
        return;
      }

      final rememberMe = await SecureStorage.getRememberMe();
      if (rememberMe == false) {
        if (kDebugMode) {
          debugPrint('Auth init | rememberMe=false | clearing tokens');
        }
        await SecureStorage.clear();
        state = state.copyWith(status: AuthStatus.unauthenticated, role: null);
        return;
      }

      if (kDebugMode) {
        final hasRefresh = await SecureStorage.getRefreshToken() != null;
        debugPrint(
          'Auth init | rememberMe=${rememberMe ?? 'null'} | refreshExists=$hasRefresh',
        );
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
      final branchId = _extractBranchIdFromToken(latestToken);

      // Role tidak diizinkan → tolak masuk.
      if (accessForRole(role) == AppAccess.denied) {
        await repo.logout();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          role: null,
          error: _accessDeniedMsg,
        );
        return;
      }

      // Success
      state = state.copyWith(status: AuthStatus.authenticated, role: role, branchId: branchId);
    } catch (e) {
      // Fail-safe → jangan bikin app stuck
      await logout();
    }
  }

  /// ---------------------------------------------------
  /// LOGIN
  /// ---------------------------------------------------
  Future<void> login(
    String email,
    String password, {
    required bool rememberMe,
  }) async {
    state = state.copyWith(loading: true, error: null);

    try {
      await repo.login(email, password, rememberMe: rememberMe);

      final accessToken = await SecureStorage.getAccessToken();
      final role = accessToken == null ? null : _extractRoleFromToken(accessToken);
      final branchId = accessToken == null ? null : _extractBranchIdFromToken(accessToken);

      // Role tidak diizinkan → batalkan login, bersihkan token.
      if (accessForRole(role) == AppAccess.denied) {
        await repo.logout();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          loading: false,
          role: null,
          error: _accessDeniedMsg,
        );
        return;
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        loading: false,
        role: role,
        branchId: branchId,
      );

      if (kDebugMode) {
        debugPrint('Auth state | authenticated | role=${role ?? '-'}');
      }
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

  @override
  void dispose() {
    _storageSub.cancel();
    super.dispose();
  }
}
