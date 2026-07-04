import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/notifications/notifications_panel.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_platform.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final auth = ref.watch(authProvider).valueOrNull;
    final location = GoRouterState.of(context).uri.path;

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.show_chart),
        label: 'Дашборд',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.sensors),
          label: 'Датчики',
        ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.account_tree),
          label: 'Группы',
        ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.group),
          label: 'Пользователи',
        ),
      const NavigationDestination(
        icon: Icon(Icons.settings),
        label: 'Настройки',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ТЭК · Мониторинг датчиков'),
        actions: [
          const NotificationBellButton(),
          if (isAdmin && isBleProvisioningSupported)
            IconButton(
              tooltip: 'Привязка ESP по BLE',
              onPressed: () => context.push('/provisioning'),
              icon: const Icon(Icons.bluetooth_searching),
            ),
          if (auth != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  auth.login,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
      body: child,
      bottomNavigationBar: destinations.length >= 2
          ? NavigationBar(
              selectedIndex: _indexForPath(location, isAdmin),
              onDestinationSelected: (index) {
                final routes = _routesForAdmin(isAdmin);
                if (index < routes.length) {
                  context.go(routes[index]);
                }
              },
              destinations: destinations,
            )
          : null,
    );
  }

  List<String> _routesForAdmin(bool isAdmin) {
    return [
      '/',
      if (isAdmin) '/sensors',
      if (isAdmin) '/groups',
      if (isAdmin) '/users',
      '/settings',
    ];
  }

  int _indexForPath(String path, bool isAdmin) {
    final routes = _routesForAdmin(isAdmin);
    if (path.startsWith('/sensors')) {
      return routes.indexOf('/sensors').clamp(0, routes.length - 1);
    }
    if (path.startsWith('/groups')) {
      return routes.indexOf('/groups').clamp(0, routes.length - 1);
    }
    if (path.startsWith('/users')) {
      return routes.indexOf('/users').clamp(0, routes.length - 1);
    }
    if (path.startsWith('/settings')) {
      return routes.indexOf('/settings').clamp(0, routes.length - 1);
    }
    return 0;
  }
}

void copyToClipboard(BuildContext context, String text, {String? message}) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message ?? 'Скопировано в буфер обмена')),
  );
}
