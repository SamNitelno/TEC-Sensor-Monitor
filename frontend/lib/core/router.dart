import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/app_shell.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/auth/forgot_password_screen.dart';
import 'package:tek_sensor_monitor/features/auth/login_screen.dart';
import 'package:tek_sensor_monitor/features/auth/register_screen.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_screen.dart';
import 'package:tek_sensor_monitor/features/groups/groups_screen.dart';
import 'package:tek_sensor_monitor/features/provisioning/provisioning_screen.dart';
import 'package:tek_sensor_monitor/features/sensors/sensors_screen.dart';
import 'package:tek_sensor_monitor/features/settings/settings_screen.dart';
import 'package:tek_sensor_monitor/features/users/users_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref);

  final Ref _ref;

  void refresh() => notifyListeners();

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    final path = state.uri.path;
    final isAuthRoute = path == '/login' ||
        path == '/register' ||
        path == '/forgot-password';
    final session = auth.valueOrNull;
    final isReady = !auth.isLoading || _ref.read(authBootstrappedProvider);

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
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  ref.listen(authProvider, (_, __) => notifier.refresh());
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
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
