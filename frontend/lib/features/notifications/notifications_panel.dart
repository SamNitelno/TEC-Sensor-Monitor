import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/notifications/notifications_providers.dart';
import 'package:tek_sensor_monitor/models/notification.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

void showNotificationsPanel(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const NotificationsPanel(),
  ).whenComplete(() {
    ref.invalidate(unreadNotificationsCountProvider);
    ref.invalidate(notificationsListProvider);
  });
}

class NotificationsPanel extends ConsumerWidget {
  const NotificationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final notificationsAsync = ref.watch(notificationsListProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Text(l10n.notificationsTitle,
                      style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(apiClientProvider)
                          .acknowledgeAllNotifications();
                      ref.invalidate(unreadNotificationsCountProvider);
                      ref.invalidate(notificationsListProvider);
                    },
                    child: Text(l10n.markAllRead),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: notificationsAsync.when(
                loading: () =>
                    TekPageLoading(message: l10n.loadingNotifications),
                error: (e, _) =>
                    Center(child: Text(friendlyApiError(e, l10n))),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(child: Text(l10n.noNewNotifications));
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _NotificationTile(item: item);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final time = DateFormat('dd.MM HH:mm').format(item.createdAt.toLocal());
    final icon = switch (item.kind) {
      'sensor_offline' => Icons.cloud_off,
      'sensor_idle' => Icons.pause_circle_outline,
      'role_promoted' => Icons.arrow_upward,
      'role_demoted' => Icons.arrow_downward,
      _ => Icons.notifications_outlined,
    };

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(item.message, style: theme.textTheme.bodySmall),
      subtitle: Text(time, style: theme.textTheme.labelSmall),
      onTap: () async {
        await ref.read(apiClientProvider).acknowledgeNotification(item.id);
        if (item.isRoleChange) {
          await ref.read(authProvider.notifier).refreshFromProfile();
        }
        ref.invalidate(unreadNotificationsCountProvider);
        ref.invalidate(notificationsListProvider);
      },
    );
  }
}

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final countAsync = ref.watch(unreadNotificationsCountProvider);
    final count = countAsync.valueOrNull ?? 0;

    return IconButton(
      tooltip: l10n.notificationsTitle,
      onPressed: () => showNotificationsPanel(context, ref),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: Colors.red,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
