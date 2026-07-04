import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/local_notifications.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/notifications/notifications_providers.dart';
import 'package:tek_sensor_monitor/models/notification.dart';

class RoleNotificationPoller extends ConsumerStatefulWidget {
  const RoleNotificationPoller({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RoleNotificationPoller> createState() =>
      _RoleNotificationPollerState();
}

class _RoleNotificationPollerState extends ConsumerState<RoleNotificationPoller> {
  Timer? _timer;
  final Set<int> _shownIds = {};
  bool _permissionPromptShown = false;

  @override
  void initState() {
    super.initState();
    LocalNotifications.init();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
    Future.microtask(_poll);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final session = ref.read(authProvider).valueOrNull;
    if (session == null) return;

    try {
      final items = await ref.read(apiClientProvider).fetchNotifications();
      if (!mounted) return;

      for (final item in items) {
        if (_shownIds.contains(item.id)) continue;
        await _present(item);
        _shownIds.add(item.id);
        if (item.isRoleChange) {
          await ref.read(apiClientProvider).acknowledgeNotification(item.id);
          await ref.read(authProvider.notifier).refreshFromProfile();
        }
        ref.invalidate(unreadNotificationsCountProvider);
      }
    } catch (_) {
      // Ignore polling errors (offline etc.)
    }
  }

  Future<void> _present(AppNotification item) async {
    final granted = await LocalNotifications.ensurePermission();
    if (granted) {
      await LocalNotifications.show(
        id: item.id,
        title: 'ТЭК · Мониторинг',
        body: item.message,
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(item.message)),
    );

    if (!_permissionPromptShown) {
      _permissionPromptShown = true;
      await _showPermissionDialog();
    }
  }

  Future<void> _showPermissionDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Уведомления отключены'),
        content: const Text(
          'Чтобы получать сообщения о повышении и понижении прав, '
          'разрешите уведомления в настройках системы или браузера.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Позже'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final granted = await LocalNotifications.ensurePermission(
                requestIfNeeded: true,
              );
              if (!granted) {
                await LocalNotifications.openSystemSettings();
              }
            },
            child: const Text('Разрешить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
