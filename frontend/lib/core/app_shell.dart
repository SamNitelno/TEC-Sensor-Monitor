import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/notifications/notifications_panel.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_platform.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
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
    final l10n = context.l10n;
    final destinations = _destinations(l10n, isAdmin);

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
    final l10n = context.l10n;
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
                for (final d in _destinations(l10n, isAdmin))
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
    final l10n = context.l10n;

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
                      l10n.navMonitoring,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      l10n.navAppSubtitle,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const ThemeModeToggleButton(),
                const NotificationBellButton(),
                if (isAdmin && isBleProvisioningSupported)
                  IconButton(
                    tooltip: l10n.bleProvisioningTooltip,
                    onPressed: () => context.push('/provisioning'),
                    icon: const Icon(Icons.bluetooth_searching),
                  ),
                if (auth != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: _UserAccountMenu(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAccountMenu extends ConsumerWidget {
  const _UserAccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth == null) return const SizedBox.shrink();

    final profile = ref.watch(profileProvider).valueOrNull;
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return PopupMenuButton<String>(
      tooltip: l10n.accountTooltip,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'settings':
            context.go('/settings');
          case 'logout':
            ref.read(authProvider.notifier).logout();
            context.go('/login');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(auth.login, style: theme.textTheme.titleSmall),
              if (profile?.email != null && profile!.email!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.mail_outline, size: 14, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        profile.email!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (profile?.phone != null && profile!.phone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        profile.phone!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined, size: 20),
            title: Text(l10n.navSettings),
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, size: 20),
            title: Text(l10n.signOut),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
      child: Chip(
        avatar: Icon(
          auth.isAdmin ? Icons.admin_panel_settings : Icons.person,
          size: 16,
        ),
        label: Text(auth.login),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

List<NavigationDestination> _destinations(AppLocalizations l10n, bool isAdmin) {
  return [
    NavigationDestination(
      icon: const Icon(Icons.show_chart_outlined),
      selectedIcon: const Icon(Icons.show_chart),
      label: l10n.navDashboard,
    ),
    if (isAdmin)
      NavigationDestination(
        icon: const Icon(Icons.sensors_outlined),
        selectedIcon: const Icon(Icons.sensors),
        label: l10n.navSensors,
      ),
    if (isAdmin)
      NavigationDestination(
        icon: const Icon(Icons.account_tree_outlined),
        selectedIcon: const Icon(Icons.account_tree),
        label: l10n.navGroups,
      ),
    if (isAdmin)
      NavigationDestination(
        icon: const Icon(Icons.group_outlined),
        selectedIcon: const Icon(Icons.group),
        label: l10n.navUsers,
      ),
    NavigationDestination(
      icon: const Icon(Icons.settings_outlined),
      selectedIcon: const Icon(Icons.settings),
      label: l10n.navSettings,
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
  final l10n = context.l10n;
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message ?? l10n.copiedToClipboard)),
  );
}
