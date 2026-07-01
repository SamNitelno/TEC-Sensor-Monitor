import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_platform.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final auth = ref.watch(authProvider).valueOrNull;
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ТЭК · Мониторинг датчиков'),
        actions: [
          if (isAdmin && isBleProvisioningSupported)
            IconButton(
              tooltip: 'Привязка ESP по BLE',
              onPressed: () => context.push('/provisioning'),
              icon: const Icon(Icons.bluetooth_searching),
            ),
          if (auth != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${auth.login} · ${auth.role}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Выйти',
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexForPath(location),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              if (isAdmin) context.go('/sensors');
            case 2:
              if (isAdmin) context.go('/groups');
          }
        },
        destinations: [
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
        ],
      ),
    );
  }

  int _indexForPath(String path) {
    if (path.startsWith('/sensors')) return 1;
    if (path.startsWith('/groups')) return 2;
    return 0;
  }
}

void copyToClipboard(BuildContext context, String text, {String? message}) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message ?? 'Скопировано в буфер обмена')),
  );
}
