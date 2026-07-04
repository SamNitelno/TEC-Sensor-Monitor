import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tek_sensor_monitor/core/local_notifications.dart';
import 'package:tek_sensor_monitor/core/router.dart';
import 'package:tek_sensor_monitor/core/theme.dart';
import 'package:tek_sensor_monitor/features/notifications/notification_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await LocalNotifications.init();
  runApp(const ProviderScope(child: TekSensorMonitorApp()));
}

class TekSensorMonitorApp extends ConsumerWidget {
  const TekSensorMonitorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return RoleNotificationPoller(
      child: MaterialApp.router(
        title: 'ТЭК · Мониторинг датчиков',
        theme: AppTheme.dark(),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
