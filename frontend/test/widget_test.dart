import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/main.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

void main() {
  testWidgets('Dashboard shows sensor selector', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sensorsProvider.overrideWith(
            (ref) async => [const Sensor(id: 1, name: 'Тестовый', status: 'online')],
          ),
          selectedSensorIdProvider.overrideWith((ref) => 1),
          readingsProvider.overrideWith(
            (ref) async => const ReadingsResponse(bucket: 'raw', points: []),
          ),
        ],
        child: const TekSensorMonitorApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Мониторинг'), findsWidgets);
    expect(find.text('Датчик'), findsOneWidget);
  });
}
