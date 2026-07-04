import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tek_sensor_monitor/core/local_notifications.dart';
import 'package:tek_sensor_monitor/core/router.dart';
import 'package:tek_sensor_monitor/core/theme.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/notifications/notification_listener.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

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
    final themePreference = ref.watch(themePreferenceProvider);
    final auth = ref.watch(authProvider);

    return RoleNotificationPoller(
      child: MaterialApp.router(
        title: 'ТЭК · Мониторинг датчиков',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themePreference.themeMode,
        scrollBehavior: const TekScrollBehavior(),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  brightness == Brightness.dark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: Theme.of(context).colorScheme.surface,
              systemNavigationBarIconBrightness:
                  brightness == Brightness.dark ? Brightness.light : Brightness.dark,
            ),
          );
          if (auth.isLoading) {
            return const Scaffold(
              body: TekPageLoading(message: 'Инициализация…'),
            );
          }
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}
