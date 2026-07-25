import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/storage/secure_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  const AuthState(this.status);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(AuthStatus.unknown)) {
    _checkToken();
  }

  Future<void> _checkToken() async {
    final hasToken = await SecureStorage.hasToken();
    state = AuthState(hasToken ? AuthStatus.authenticated : AuthStatus.unauthenticated);
  }

  /// Login with PIN — returns null on success, error message on failure.
  Future<String?> login(String pin) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        data: {'pin': pin},
      );
      final token = response.data['token'] as String;
      await SecureStorage.saveToken(token);
      state = const AuthState(AuthStatus.authenticated);
      return null;
    } catch (e) {
      return extractApiError(e);
    }
  }

  Future<void> logout() async {
    await SecureStorage.deleteToken();
    state = const AuthState(AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
