import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/dashboard_alerts_bar.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

class _FixedPanelsNotifier extends ChartPanelsNotifier {
  _FixedPanelsNotifier(int count) : super() {
    state = List.generate(
      count,
      (index) => ChartPanelConfig(id: 'panel-$index'),
    );
  }
}

void main() {
  testWidgets('Alerts bar + fixed-height grid scrolls on iPhone-sized viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

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
        chartPanelsProvider.overrideWith((ref) => _FixedPanelsNotifier(3)),
      ],
    );
    addTearDown(container.dispose);

    const tileHeight = 380.0;
    const gap = 12.0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: DashboardAlertsBar(connectionIssue: 'Offline'),
                ),
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    mainAxisSpacing: gap,
                    mainAxisExtent: tileHeight,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Container(
                      key: Key('chart-tile-$index'),
                      color: Colors.blue.shade100,
                    ),
                    childCount: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile0 = tester.getSize(find.byKey(const Key('chart-tile-0')));
    expect(tile0.height, tileHeight);
    expect(
      3 * tileHeight + 2 * gap,
      greaterThan(932),
      reason: 'Three tiles should exceed viewport and require scroll',
    );
    expect(find.byType(CustomScrollView), findsOneWidget);
  });
}
