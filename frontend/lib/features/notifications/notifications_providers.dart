import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/models/notification.dart';

final unreadNotificationsCountProvider =
    StreamProvider.autoDispose<int>((ref) async* {
  final session = ref.watch(authProvider).valueOrNull;
  if (session == null) {
    yield 0;
    return;
  }

  final client = ref.watch(apiClientProvider);
  yield await client.fetchUnreadNotificationCount();

  final timer = Timer.periodic(const Duration(seconds: 10), (_) {});
  ref.onDispose(timer.cancel);

  await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
    try {
      yield await client.fetchUnreadNotificationCount();
    } catch (_) {
      // keep last value on error
    }
  }
});

final notificationsListProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final session = ref.watch(authProvider).valueOrNull;
  if (session == null) return [];
  return ref.watch(apiClientProvider).fetchNotifications();
});
