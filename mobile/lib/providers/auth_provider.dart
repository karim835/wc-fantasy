import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.login(email, password);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(user: user, isAuthenticated: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e),
        isAuthenticated: false,
      );
      rethrow;
    }
  }

  Future<void> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.register(username, email, password);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(user: user, isAuthenticated: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e), isAuthenticated: false);
      rethrow;
    }
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await apiService.getProfile();
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(user: user, isAuthenticated: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, isAuthenticated: false, error: _parseError(e));
    }
  }

  Future<void> logout() async {
    await apiService.logout();
    state = const AuthState();
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Invalid credentials')) return 'Email ou mot de passe incorrect';
    if (msg.contains('409') || msg.contains('already')) return 'Email ou username déjà utilisé';
    if (msg.contains('network') || msg.contains('connection')) return 'Erreur réseau. Vérifiez votre connexion';
    return 'Une erreur est survenue';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

// Fetches the live profile via the token-authenticated endpoint. This does NOT
// depend on `authProvider` (which the login flow never populates) — it reads
// straight from `/auth/profile`, the same source the rest of the app trusts.
// autoDispose so it re-fetches each time a gated screen is opened (e.g. after
// logging in as a different account).
final myProfileProvider = FutureProvider.autoDispose<User?>((ref) async {
  try {
    final data = await apiService.getProfile();
    return User.fromJson(data['user'] as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

// Whether the logged-in account is a site admin (derived from the profile).
final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = await ref.watch(myProfileProvider.future);
  return user?.isAdmin ?? false;
});
