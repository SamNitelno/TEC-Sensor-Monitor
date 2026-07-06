import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/api_client.dart';
import 'package:tek_sensor_monitor/core/api_url_provider.dart';
import 'package:tek_sensor_monitor/core/auth_storage.dart';
import 'package:tek_sensor_monitor/core/jwt_utils.dart';
import 'package:tek_sensor_monitor/models/auth_capabilities.dart';
import 'package:tek_sensor_monitor/models/auth_session.dart';
import 'package:tek_sensor_monitor/models/notification.dart';
import 'package:tek_sensor_monitor/models/user.dart';

/// True after the first auth session restore completes (cold start).
final authBootstrappedProvider = StateProvider<bool>((ref) => false);

final authStorageProvider = FutureProvider<AuthStorage>((ref) async {
  return AuthStorage.create();
});

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  bool _logoutInFlight = false;
  bool _loginInFlight = false;

  @override
  Future<AuthSession?> build() async {
    final storage = await ref.watch(authStorageProvider.future);
    final token = storage.token;
    if (token == null || token.isEmpty) {
      return null;
    }
    if (isJwtExpired(token)) {
      await storage.clear();
      return null;
    }
    return AuthSession(
      token: token,
      role: storage.role ?? 'viewer',
      login: storage.login ?? '',
    );
  }

  Future<void> _saveSessionToStorage(AuthSession session) async {
    final storage = await ref.read(authStorageProvider.future);
    await storage.saveSession(
      token: session.token,
      role: session.role,
      login: session.login,
    );
  }

  Future<void> _persistSession(AuthSession session) async {
    await _saveSessionToStorage(session);
    state = AsyncData(session);
  }

  Future<void> login(String login, String password) async {
    if (_loginInFlight || state.isLoading) return;
    _loginInFlight = true;
    try {
      state = await AsyncValue.guard(() async {
        final client = ref.read(rawApiClientProvider);
        final session = await client.login(login, password);
        await _saveSessionToStorage(session);
        return session;
      });
    } finally {
      _loginInFlight = false;
    }
  }

  Future<void> register(String login, String password) async {
    if (state.isLoading) return;
    state = await AsyncValue.guard(() async {
      final client = ref.read(rawApiClientProvider);
      final session = await client.register(login, password);
      await _saveSessionToStorage(session);
      return session;
    });
  }

  Future<void> refreshFromProfile() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final profile = await ref.read(apiClientProvider).fetchProfile();
    await applyProfileUpdate(
      ProfileUpdateResult(profile: profile, accessToken: null),
    );
  }

  Future<void> applyProfileUpdate(ProfileUpdateResult result) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _persistSession(
      AuthSession(
        token: result.accessToken ?? current.token,
        role: result.profile.role,
        login: result.profile.login,
      ),
    );
    ref.invalidate(profileProvider);
  }

  Future<void> logout() async {
    if (_logoutInFlight || state.valueOrNull == null) {
      return;
    }
    _logoutInFlight = true;
    try {
      final storage = await ref.read(authStorageProvider.future);
      await storage.clear();
      state = const AsyncData(null);
      ref.invalidate(profileProvider);
    } finally {
      _logoutInFlight = false;
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthSession?>(
  AuthNotifier.new,
);

final rawApiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider).requireValue;
  return ApiClient(baseUrl: baseUrl);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authProvider).valueOrNull;
  final baseUrl = ref.watch(apiBaseUrlProvider).requireValue;
  return ApiClient(
    baseUrl: baseUrl,
    getToken: () => auth?.token,
    onUnauthorized: () {
      if (ref.read(authProvider).valueOrNull != null) {
        ref.read(authProvider.notifier).logout();
      }
    },
  );
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).valueOrNull?.isAdmin ?? false;
});

final profileProvider = FutureProvider<UserProfile>((ref) async {
  final session = ref.watch(authProvider).valueOrNull;
  if (session == null) {
    throw StateError('not authenticated');
  }
  final client = ref.watch(apiClientProvider);
  return client.fetchProfile();
});

final usersProvider = FutureProvider<List<UserListItem>>((ref) async {
  final session = ref.watch(authProvider).valueOrNull;
  if (session == null) return [];
  final client = ref.watch(apiClientProvider);
  return client.fetchUsers();
});

final authCapabilitiesProvider = FutureProvider<AuthCapabilities>((ref) async {
  return ref.read(rawApiClientProvider).fetchAuthCapabilities();
});
