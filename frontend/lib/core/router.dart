import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/app_shell.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/auth/login_screen.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_screen.dart';
import 'package:tek_sensor_monitor/features/groups/groups_screen.dart';
import 'package:tek_sensor_monitor/features/provisioning/provisioning_screen.dart';
import 'package:tek_sensor_monitor/features/sensors/sensors_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggingIn = state.uri.path == '/login';
      final session = auth.valueOrNull;
      final isReady = !auth.isLoading;

      if (!isReady) {
        return null;
      }
      if (session == null && !loggingIn) {
        return '/login';
      }
      if (session != null && loggingIn) {
        return '/';
      }
      if (state.uri.path == '/sensors' || state.uri.path == '/groups') {
        if (session != null && !session.isAdmin) {
          return '/';
        }
      }
      if (state.uri.path == '/provisioning') {
        if (session != null && !session.isAdmin) {
          return '/';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/sensors',
            builder: (context, state) => const SensorsScreen(),
          ),
          GoRoute(
            path: '/groups',
            builder: (context, state) => const GroupsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/provisioning',
        builder: (context, state) => const ProvisioningScreen(),
      ),
    ],
  );
});
