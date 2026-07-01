import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/api_client.dart';
import 'package:tek_sensor_monitor/core/auth_storage.dart';
import 'package:tek_sensor_monitor/models/auth_session.dart';

final authStorageProvider = FutureProvider<AuthStorage>((ref) async {
  return AuthStorage.create();
});

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final storage = await ref.watch(authStorageProvider.future);
    final token = storage.token;
    if (token == null) {
      return null;
    }
    return AuthSession(
      token: token,
      role: storage.role ?? 'viewer',
      login: storage.login ?? '',
    );
  }

  Future<void> login(String login, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(rawApiClientProvider);
      final session = await client.login(login, password);
      final storage = await ref.read(authStorageProvider.future);
      await storage.saveSession(
        token: session.token,
        role: session.role,
        login: session.login,
      );
      return session;
    });
  }

  Future<void> logout() async {
    final storage = await ref.read(authStorageProvider.future);
    await storage.clear();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthSession?>(
  AuthNotifier.new,
);

final rawApiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authProvider).valueOrNull;
  return ApiClient(getToken: () => auth?.token);
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).valueOrNull?.isAdmin ?? false;
});
