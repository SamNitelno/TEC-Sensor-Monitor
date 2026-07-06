import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_ws.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/chart_panel_card.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/dashboard_alerts_bar.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(dashboardPollTickProvider.notifier).state++;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dashboardWsServiceProvider);
    final l10n = context.l10n;
    final workshopsAsync = ref.watch(workshopsProvider);
    final panels = ref.watch(chartPanelsProvider);
    final connectionIssue = _connectionIssue(workshopsAsync, l10n);

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cols = dashboardGridColumns(panels.length, constraints.maxWidth);
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.chartsTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                ref.read(chartPanelsProvider.notifier).addPanel(),
                            icon: const Icon(Icons.add_chart, size: 16),
                            label: Text(l10n.addChart),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DashboardAlertsBar(connectionIssue: connectionIssue),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: _DashboardChartGrid.gap,
                      mainAxisSpacing: _DashboardChartGrid.gap,
                      mainAxisExtent: _DashboardChartGrid.minChartHeight,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final panel = panels[index];
                        return ChartPanelCard(
                          key: ValueKey(panel.id),
                          panelId: panel.id,
                          panelIndex: index,
                          canRemove: panels.length > 1,
                          connectionIssue: connectionIssue,
                        );
                      },
                      childCount: panels.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _connectionIssue(AsyncValue workshops, AppLocalizations l10n) {
    if (workshops.hasError && isConnectionError(workshops.error!)) {
      return l10n.connectionIssueBanner;
    }
    return null;
  }
}

class _DashboardChartGrid {
  static const gap = 12.0;
  /// Full tile height (header + filters + chart). Chart area keeps >= [_minChartAreaHeight].
  static const minChartHeight = 380.0;
  static const minChartAreaHeight = 260.0;
}
