import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tek_sensor_monitor/main.dart';

void main() {
  testWidgets('Home screen shows title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TekSensorMonitorApp(),
      ),
    );
    expect(find.textContaining('Мониторинг'), findsWidgets);
  });
}
