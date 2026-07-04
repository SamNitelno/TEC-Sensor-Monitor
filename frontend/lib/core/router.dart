import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/app_shell.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/auth/login_screen.dart';
import 'package:tek_sensor_monitor/features/auth/register_screen.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_screen.dart';
import 'package:tek_sensor_monitor/features/groups/groups_screen.dart';
import 'package:tek_sensor_monitor/features/provisioning/provisioning_screen.dart';
import 'package:tek_sensor_monitor/features/sensors/sensors_screen.dart';
import 'package:tek_sensor_monitor/features/settings/settings_screen.dart';
import 'package:tek_sensor_monitor/features/users/users_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final path = state.uri.path;
      final isAuthRoute = path == '/login' || path == '/register';
      final session = auth.valueOrNull;
      final isReady = !auth.isLoading;

      if (!isReady) {
        return null;
      }
      if (session == null && !isAuthRoute) {
        return '/login';
      }
      if (session != null && isAuthRoute) {
        return '/';
      }
      if (path == '/sensors' ||
          path == '/groups' ||
          path == '/users' ||
          path == '/provisioning') {
        if (session != null && !session.isAdmin) {
          return '/';
        }
      }
      if (path == '/settings' && session == null) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
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
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
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
