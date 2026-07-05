import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/dashboard_alerts_bar.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

class _EmptyPanelsNotifier extends ChartPanelsNotifier {
  _EmptyPanelsNotifier() : super() {
    state = const [];
  }
}

void main() {
  testWidgets('DashboardAlertsBar sits above chart and preserves chart height', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));

    final container = ProviderContainer(
      overrides: [
        sensorsProvider.overrideWith(
          (ref) async => [
            const Sensor(
              id: 1,
              name: 'ESP Test',
              deviceId: 'dev-1',
              siteId: null,
              status: 'offline',
              lastSeen: null,
            ),
          ],
        ),
        chartPanelsProvider.overrideWith((ref) => _EmptyPanelsNotifier()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                const DashboardAlertsBar(connectionIssue: 'No server connection'),
                Expanded(
                  child: Container(key: const Key('chart-area'), color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chartBox = tester.getRect(find.byKey(const Key('chart-area')));
    expect(chartBox.height, greaterThan(500));
    expect(find.textContaining('No server connection'), findsOneWidget);
    expect(find.textContaining('ESP Test'), findsOneWidget);
  });
}
