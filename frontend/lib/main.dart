import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/router.dart';
import 'package:tek_sensor_monitor/core/theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: TekSensorMonitorApp(),
    ),
  );
}

class TekSensorMonitorApp extends StatelessWidget {
  const TekSensorMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ТЭК · Мониторинг датчиков',
      theme: AppTheme.dark(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
