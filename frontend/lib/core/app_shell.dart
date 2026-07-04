import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/notifications/notifications_panel.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_platform.dart';
import 'package:tek_sensor_monitor/widgets/tek_logo.dart';
import 'package:tek_sensor_monitor/widgets/theme_mode_toggle.dart';

const _railBreakpoint = 900.0;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= _railBreakpoint;

    if (useRail) {
      return _RailShell(child: child);
    }
    return _MobileShell(child: child);
  }
}

class _MobileShell extends ConsumerWidget {
  const _MobileShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final location = GoRouterState.of(context).uri.path;
    final destinations = _destinations(isAdmin);

    return Scaffold(
      appBar: _TekAppBar(showLogo: true),
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
}

class _RailShell extends ConsumerWidget {
  const _RailShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final location = GoRouterState.of(context).uri.path;
    final theme = Theme.of(context);
    final selectedIndex = _indexForPath(location, isAdmin);

    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                final routes = _routesForAdmin(isAdmin);
                if (index < routes.length) {
                  context.go(routes[index]);
                }
              },
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: const TekLogo(height: 40),
              ),
              destinations: [
                for (final d in _destinations(isAdmin))
                  NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon ?? d.icon,
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: theme.dividerColor),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TekAppBar(showLogo: false),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TekAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _TekAppBar({required this.showLogo});

  final bool showLogo;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final auth = ref.watch(authProvider).valueOrNull;
    final theme = Theme.of(context);

    return Material(
      color: theme.appBarTheme.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (showLogo) ...[
                  const TekLogo(height: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Мониторинг',
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      'ТЭК · Мониторинг датчиков',
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const ThemeModeToggleButton(),
                const NotificationBellButton(),
                if (isAdmin && isBleProvisioningSupported)
                  IconButton(
                    tooltip: 'Привязка ESP по BLE',
                    onPressed: () => context.push('/provisioning'),
                    icon: const Icon(Icons.bluetooth_searching),
                  ),
                if (auth != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: Icon(
                        auth.isAdmin ? Icons.admin_panel_settings : Icons.person,
                        size: 16,
                      ),
                      label: Text(auth.login),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<NavigationDestination> _destinations(bool isAdmin) {
  return [
    const NavigationDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: 'Дашборд',
    ),
    if (isAdmin)
      const NavigationDestination(
        icon: Icon(Icons.sensors_outlined),
        selectedIcon: Icon(Icons.sensors),
        label: 'Датчики',
      ),
    if (isAdmin)
      const NavigationDestination(
        icon: Icon(Icons.account_tree_outlined),
        selectedIcon: Icon(Icons.account_tree),
        label: 'Группы',
      ),
    if (isAdmin)
      const NavigationDestination(
        icon: Icon(Icons.group_outlined),
        selectedIcon: Icon(Icons.group),
        label: 'Пользователи',
      ),
    const NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Настройки',
    ),
  ];
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

void copyToClipboard(BuildContext context, String text, {String? message}) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message ?? 'Скопировано в буфер обмена')),
  );
}
