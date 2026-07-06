import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tek_sensor_monitor/core/api_url_provider.dart';
import 'package:tek_sensor_monitor/core/locale/locale_provider.dart';
import 'package:tek_sensor_monitor/core/local_notifications.dart';
import 'package:tek_sensor_monitor/core/router.dart';
import 'package:tek_sensor_monitor/core/startup_log.dart';
import 'package:tek_sensor_monitor/core/theme.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/notifications/notification_listener.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await safeInit('dateFormatting.ru', () => initializeDateFormatting('ru'));
      await safeInit('dateFormatting.en', () => initializeDateFormatting('en'));
      await safeInit('preloadFonts', TekMotion.preloadFonts);

      final initialLanguage = AppLanguage.resolveSystemLanguage();
      await safeInit(
        'localNotifications',
        () => LocalNotifications.init(
          channelName: initialLanguage == AppLanguage.russian
              ? 'Изменения прав'
              : 'Role changes',
          channelDescription: initialLanguage == AppLanguage.russian
              ? 'Повышение и понижение пользователей'
              : 'User promotions and demotions',
        ),
      );

      runApp(const ProviderScope(child: TekSensorMonitorApp()));
    },
    (error, stack) {
      logStartupError(error, stack);
    },
  );
}

class TekSensorMonitorApp extends ConsumerWidget {
  const TekSensorMonitorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiBaseUrlAsync = ref.watch(apiBaseUrlProvider);
    final router = ref.watch(routerProvider);
    final themePreference = ref.watch(themePreferenceProvider);
    final language = ref.watch(languagePreferenceProvider);
    final auth = ref.watch(authProvider);
    final bootstrapped = ref.watch(authBootstrappedProvider);

    ref.listen(authProvider, (previous, next) {
      if (!next.isLoading) {
        ref.read(authBootstrappedProvider.notifier).state = true;
      }
    });

    return apiBaseUrlAsync.when(
      loading: () => MaterialApp(
        home: Scaffold(
          body: TekPageLoading(
            message: language == AppLanguage.russian
                ? 'Инициализация…'
                : 'Initializing…',
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
      error: (error, _) => MaterialApp(
        home: Scaffold(
          body: Center(child: Text(error.toString())),
        ),
        debugShowCheckedModeBanner: false,
      ),
      data: (_) => MaterialApp.router(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        title: language == AppLanguage.russian
            ? 'ТЭК · Мониторинг датчиков'
            : 'TEK · Sensor monitoring',
        locale: language.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themePreference.themeMode,
        themeAnimationDuration: TekMotion.themeSwitch,
        themeAnimationCurve: Curves.linear,
        scrollBehavior: const TekScrollBehavior(),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarColor: Theme.of(context).colorScheme.surface,
              systemNavigationBarIconBrightness: brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );
          final content = auth.isLoading && !bootstrapped
              ? Scaffold(
                  body: TekPageLoading(
                    message: AppLocalizations.of(context).initializing,
                  ),
                )
              : (child ?? const SizedBox.shrink());
          return RoleNotificationPoller(child: content);
        },
      ),
    );
  }
}
