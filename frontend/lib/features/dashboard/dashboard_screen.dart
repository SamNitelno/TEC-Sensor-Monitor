import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/chart_panel_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;
  bool _connectionSnackShown = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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
    final l10n = context.l10n;
    final workshopsAsync = ref.watch(workshopsProvider);
    final panels = ref.watch(chartPanelsProvider);
    final connectionIssue = _connectionIssue(workshopsAsync, l10n);

    if (connectionIssue != null && !_connectionSnackShown) {
      _connectionSnackShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(connectionIssue),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    } else if (connectionIssue == null) {
      _connectionSnackShown = false;
    }

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
            Expanded(
              child: _DashboardChartGrid(
                panels: panels,
                connectionIssue: connectionIssue,
              ),
            ),
          ],
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

class _DashboardChartGrid extends StatelessWidget {
  const _DashboardChartGrid({
    required this.panels,
    required this.connectionIssue,
  });

  final List<ChartPanelConfig> panels;
  final String? connectionIssue;

  static const _gap = 12.0;
  static const _minTileHeight = 300.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = dashboardGridColumns(panels.length, constraints.maxWidth);
        final rows = (panels.length / cols).ceil();
        final totalMinHeight = rows * _minTileHeight + (rows - 1) * _gap;
        final scrollable = totalMinHeight > constraints.maxHeight;
        final tileHeight = scrollable
            ? _minTileHeight
            : (constraints.maxHeight - (rows - 1) * _gap) / rows;

        final grid = GridView.builder(
          padding: EdgeInsets.zero,
          physics: scrollable
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: _gap,
            mainAxisSpacing: _gap,
            mainAxisExtent: tileHeight,
          ),
          itemCount: panels.length,
          itemBuilder: (context, index) {
            final panel = panels[index];
            return ChartPanelCard(
              key: ValueKey(panel.id),
              panelId: panel.id,
              panelIndex: index,
              canRemove: panels.length > 1,
              connectionIssue: connectionIssue,
            );
          },
        );

        return grid;
      },
    );
  }
}
