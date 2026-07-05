import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/dashboard/chart_series_utils.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_ws.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/chart_time_control_bar.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/current_chart.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/group_filter_panel.dart';
import 'package:tek_sensor_monitor/models/downtime.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/models/site.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
import 'package:tek_sensor_monitor/widgets/tek_interactive.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

class ChartPanelCard extends ConsumerWidget {
  const ChartPanelCard({
    super.key,
    required this.panelId,
    required this.panelIndex,
    required this.canRemove,
    this.connectionIssue,
  });

  final String panelId;
  final int panelIndex;
  final bool canRemove;
  final String? connectionIssue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final panels = ref.watch(chartPanelsProvider);
    final panel = panels.firstWhere((p) => p.id == panelId);
    final range = ref.watch(panelTimeRangeProvider(panelId));
    final readingsAsync = ref.watch(mergedPanelReadingsProvider(panelId));
    final cachedReadings = ref.watch(panelReadingsCacheProvider(panelId));
    final downtimeEventsAsync = ref.watch(panelDowntimeEventsProvider(panelId));
    final workshopsAsync = ref.watch(workshopsProvider);
    final sitesAsync = ref.watch(panelSitesProvider(panelId));
    final sensorsAsync = ref.watch(panelSensorsProvider(panelId));
    final allSitesAsync = ref.watch(sitesProvider);
    final cachedWorkshops = ref.watch(workshopsCacheProvider);
    final cachedSites = ref.watch(panelSitesCacheProvider(panelId));
    final cachedSensors = ref.watch(panelSensorsCacheProvider(panelId));
    final workshops = workshopsAsync.valueOrNull ?? cachedWorkshops ?? [];
    final sites = sitesAsync.valueOrNull ?? cachedSites ?? [];
    final sensors = sensorsAsync.valueOrNull ?? cachedSensors ?? [];
    final allSitesForFilter = allSitesAsync.valueOrNull ?? sites;

    final presetSelected =
        panel.isLive && panel.liveSpan == null && panel.customRange == null;
    final hasCustom = !panel.isLive && panel.customRange != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (panel.isLive) ...[
                  const LivePulseDot(),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    panel.displayTitle(panelIndex, l10n),
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: l10n.renameTooltip,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _renamePanel(context, ref, panel),
                ),
                if (canRemove)
                  IconButton(
                    tooltip: l10n.removeChartTooltip,
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        ref.read(chartPanelsProvider.notifier).removePanel(panelId),
                  ),
              ],
            ),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                childrenPadding: const EdgeInsets.only(bottom: 2),
                expandedAlignment: Alignment.centerLeft,
                title: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.groupingLabel,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                initiallyExpanded: false,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: GroupFilterPanel(
                    embedded: true,
                    workshopsAsync: workshopsAsync,
                    sitesAsync: sitesAsync,
                    sensorsAsync: sensorsAsync,
                    cachedWorkshops: cachedWorkshops,
                    cachedSites: cachedSites,
                    cachedSensors: cachedSensors,
                    allSitesForFilter: allSitesForFilter,
                    selectedSensorIds: panel.selectedSensorIds,
                    allSensorsSelected: panel.allSensors,
                    selectedWorkshopIds: panel.workshopIds,
                    selectedSiteIds: panel.siteIds,
                    connectionIssue: connectionIssue,
                    onWorkshopsAll: () => setPanelWorkshopsAll(ref, panelId),
                    onWorkshopToggle: (id, selected) =>
                        togglePanelWorkshop(ref, panelId, id, selected),
                    onSitesAll: () => setPanelSitesAll(ref, panelId),
                    onSiteToggle: (id, selected) =>
                        togglePanelSite(ref, panelId, id, selected),
                    onAllSensors: () => setPanelAllSensors(ref, panelId),
                    onSensorToggle: (id, selected) =>
                        togglePanelSensor(ref, panelId, id, selected),
                      ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ChartTimeControlBar(
              preset: panel.preset,
              presetSelected: presetSelected,
              hasCustom: hasCustom,
              onPreset: (value) => updatePanelPreset(ref, panelId, value),
              onCustom: () => _pickCustomRange(context, ref, panel),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _buildChartArea(
                ref: ref,
                theme: theme,
                l10n: l10n,
                readingsAsync: readingsAsync,
                cachedReadings: cachedReadings,
                panel: panel,
                range: range,
                workshops: workshops,
                sites: sites,
                sensors: sensors,
                downtimeEvents:
                    downtimeEventsAsync.valueOrNull ?? const [],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renamePanel(
    BuildContext context,
    WidgetRef ref,
    ChartPanelConfig panel,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: panel.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameChartTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.renameChartHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      ref.read(chartPanelsProvider.notifier).updatePanel(
            panelId,
            (p) => p.copyWith(title: result.trim()),
          );
    }
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    WidgetRef ref,
    ChartPanelConfig panel,
  ) async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final custom = panel.customRange;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now,
      initialDateRange: custom != null
          ? DateTimeRange(start: custom.start, end: custom.end)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 1)),
              end: now,
            ),
      helpText: l10n.customRangeHelp,
    );
    if (picked != null) {
      setPanelHistoricalWindow(
        ref,
        panelId,
        TimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        ),
      );
      final span = picked.end.difference(picked.start);
      updatePanelScaleFromZoom(
        ref,
        panelId,
        chartScaleForVisibleSpan(span),
      );
    }
  }

  Widget _buildChartArea({
    required WidgetRef ref,
    required ThemeData theme,
    required AppLocalizations l10n,
    required AsyncValue<GroupedReadingsResponse> readingsAsync,
    required GroupedReadingsResponse? cachedReadings,
    required ChartPanelConfig panel,
    required TimeRange range,
    required List<Workshop> workshops,
    required List<Site> sites,
    required List<Sensor> sensors,
    List<DowntimeEvent> downtimeEvents = const [],
  }) {
    var response = readingsAsync.valueOrNull ?? cachedReadings;

    if (response != null) {
      final allowedIds = <int>{};
      if (!panel.allSensors && panel.selectedSensorIds.isNotEmpty) {
        allowedIds.addAll(panel.selectedSensorIds);
      } else {
        allowedIds.addAll(sensors.map((s) => s.id));
      }
      if (allowedIds.isNotEmpty) {
        response = GroupedReadingsResponse(
          series: response.series
              .where((s) => allowedIds.contains(s.sensorId))
              .toList(),
        );
      } else if (panel.workshopIds.isNotEmpty || panel.siteIds.isNotEmpty) {
        response = const GroupedReadingsResponse(series: []);
      }
    }

    if (response == null) {
      return readingsAsync.when(
        loading: () => const Center(child: TekPageLoading()),
        error: (error, _) => ChartMessagePanel(
          icon: Icons.error_outline,
          title: l10n.loadDataErrorTitle,
          subtitle: friendlyApiError(error, l10n),
          color: theme.colorScheme.error,
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }

    final isRefreshing = readingsAsync.isLoading;
    final hasError = readingsAsync.hasError;

    return _chartContent(
      ref: ref,
      theme: theme,
      l10n: l10n,
      response: response,
      panel: panel,
      range: range,
      workshops: workshops,
      sites: sites,
      sensors: sensors,
      isStale: isRefreshing || hasError,
      errorMessage: hasError
          ? (connectionIssue ?? friendlyApiError(readingsAsync.error!, l10n))
          : connectionIssue,
      downtimeEvents: downtimeEvents,
    );
  }

  Widget _chartContent({
    required WidgetRef ref,
    required ThemeData theme,
    required AppLocalizations l10n,
    required GroupedReadingsResponse response,
    required ChartPanelConfig panel,
    required TimeRange range,
    required List<Workshop> workshops,
    required List<Site> sites,
    required List<Sensor> sensors,
    required bool isStale,
    String? errorMessage,
    List<DowntimeEvent> downtimeEvents = const [],
  }) {
    final chartSeries =
        response.series.where((s) => s.points.isNotEmpty).toList();
    if (chartSeries.isEmpty) {
      return ChartMessagePanel(
        icon: Icons.show_chart,
        title: l10n.noDataForPeriodTitle,
        subtitle: l10n.noDataForPeriodSubtitle,
        color: theme.colorScheme.secondary,
        compact: true,
      );
    }

    final pointsCount =
        chartSeries.fold<int>(0, (sum, s) => sum + s.points.length);
    DateTime? latestPointTime;
    for (final series in chartSeries) {
      for (final point in series.points) {
        if (latestPointTime == null || point.time.isAfter(latestPointTime)) {
          latestPointTime = point.time;
        }
      }
    }

    Sensor? sensorById(int id) {
      for (final sensor in sensors) {
        if (sensor.id == id) return sensor;
      }
      return null;
    }

    final showOffline =
        isStale || errorMessage != null || connectionIssue != null;

    final chartSeriesData = [
      for (var i = 0; i < chartSeries.length; i++)
        ChartSeriesData(
          sensorId: chartSeries[i].sensorId,
          sensorName: chartSeries[i].sensorName,
          segments: splitPointsAtGaps(
            chartSeries[i].points,
            gapThresholdForScale(panel.scale),
          ),
          color: resolveChartSeriesColor(
            sensor: sensorById(chartSeries[i].sensorId) ??
                Sensor(
                  id: chartSeries[i].sensorId,
                  name: chartSeries[i].sensorName,
                  deviceId: '',
                  siteId: null,
                  status: 'offline',
                  lastSeen: null,
                ),
            workshopFilterIds: panel.workshopIds,
            siteFilterIds: panel.siteIds,
            workshops: workshops,
            sites: sites,
            fallbackIndex: i,
          ),
        ),
    ];

    final bands = [
      ..._zeroCurrentBandsFromSeries(chartSeriesData, range.start, range.end),
      ..._offlineBandsForChart(downtimeEvents, range),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.chartStats(pointsCount, chartSeries.length),
                style: theme.textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showOffline)
              const Chip(
                avatar: Icon(Icons.cloud_off, size: 14),
                label: Text('offline'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: EdgeInsets.only(right: 6),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: CurrentChart(
            key: ValueKey(panelId),
            series: chartSeriesData,
            scale: panel.scale,
            rangeStart: range.start,
            rangeEnd: range.end,
            isLiveWindow: panel.isLive,
            downtimeBands: bands,
            onWheelZoom: (delta) => applyPanelWheelZoom(ref, panelId, delta),
            onVisibleRangeChanged: (start, end) {
              final span = end.difference(start);
              final isLive = end.isAfter(
                DateTime.now().subtract(const Duration(minutes: 2)),
              );
              updatePanelScaleFromZoom(
                ref,
                panelId,
                chartScaleForVisibleSpan(span),
              );
              if (isLive) {
                setPanelLiveWindow(ref, panelId, span: span);
              } else {
                setPanelHistoricalWindow(
                  ref,
                  panelId,
                  TimeRange(start: start, end: end),
                );
              }
            },
          ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Near-zero phase current (A) — orange shading on the chart.
const double _zeroCurrentEpsilonA = 0.05;

List<ChartDowntimeBand> _zeroCurrentBandsFromSeries(
  List<ChartSeriesData> series,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final bands = <ChartDowntimeBand>[];

  for (final item in series) {
    for (final segment in item.segments) {
      if (segment.isEmpty) continue;

      DateTime? bandStart;
      for (var i = 0; i < segment.length; i++) {
        final point = segment[i];
        final isZero = point.avg.abs() < _zeroCurrentEpsilonA;
        if (isZero) {
          bandStart ??= point.time;
        } else if (bandStart != null) {
          bands.add(
            ChartDowntimeBand(
              start: bandStart,
              end: segment[i - 1].time,
              type: 'idle',
            ),
          );
          bandStart = null;
        }
      }
      if (bandStart != null) {
        bands.add(
          ChartDowntimeBand(
            start: bandStart,
            end: segment.last.time,
            type: 'idle',
          ),
        );
      }
    }
  }

  final clipped = <ChartDowntimeBand>[];
  for (final band in bands) {
    final start = band.start.isBefore(rangeStart) ? rangeStart : band.start;
    final end = band.end.isAfter(rangeEnd) ? rangeEnd : band.end;
    if (end.isAfter(start)) {
      clipped.add(ChartDowntimeBand(start: start, end: end, type: 'idle'));
    }
  }
  return clipped;
}

List<ChartDowntimeBand> _offlineBandsForChart(
  List<DowntimeEvent> events,
  TimeRange range,
) {
  final now = DateTime.now().toUtc();
  final bands = <ChartDowntimeBand>[];
  for (final event in events.where((e) => e.isOffline)) {
    final rawEnd = event.endedAt ?? now;
    final start =
        event.startedAt.isBefore(range.start) ? range.start : event.startedAt;
    final end = rawEnd.isAfter(range.end) ? range.end : rawEnd;
    if (!end.isAfter(start)) continue;
    bands.add(
      ChartDowntimeBand(start: start, end: end, type: 'offline'),
    );
  }
  return bands;
}

class ChartMessagePanel extends StatelessWidget {
  const ChartMessagePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: compact ? 32 : 48, color: color),
            SizedBox(height: compact ? 8 : 16),
            Text(
              title,
              style: compact
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
