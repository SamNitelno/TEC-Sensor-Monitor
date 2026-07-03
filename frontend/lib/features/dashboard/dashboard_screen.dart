import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/current_chart.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/group_filter_panel.dart';

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
      ref.invalidate(readingsProvider);
      ref.invalidate(sensorsProvider);
      ref.invalidate(workshopsProvider);
      if (ref.read(workshopFilterProvider) != null) {
        ref.invalidate(sitesProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String? _connectionIssue(
    AsyncValue workshops,
    AsyncValue sites,
    AsyncValue sensors,
  ) {
    for (final async in [workshops, sites, sensors]) {
      if (async.hasError && isConnectionError(async.error!)) {
        return 'Нет связи с сервером — показаны последние известные данные';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sensorsAsync = ref.watch(sensorsProvider);
    final sitesAsync = ref.watch(sitesProvider);
    final workshopsAsync = ref.watch(workshopsProvider);
    final cachedWorkshops = ref.watch(workshopsCacheProvider);
    final cachedSites = ref.watch(sitesCacheProvider);
    final cachedSensors = ref.watch(sensorsCacheProvider);
    final cachedReadings = ref.watch(readingsCacheProvider);
    final selectedIds = ref.watch(selectedSensorIdsProvider);
    final siteId = ref.watch(siteFilterProvider);
    final workshopId = ref.watch(workshopFilterProvider);
    final preset = ref.watch(timeRangePresetProvider);
    final customRange = ref.watch(customTimeRangeProvider);
    final isLiveWindow = ref.watch(chartLiveWindowProvider);
    final liveSpan = ref.watch(chartWindowSpanProvider);
    final scale = ref.watch(chartScaleProvider);
    final range = ref.watch(timeRangeProvider);
    final readingsAsync = ref.watch(readingsProvider);

    final connectionIssue = _connectionIssue(workshopsAsync, sitesAsync, sensorsAsync);
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

    ref.listen(sensorsProvider, (previous, next) {
      next.whenData((sensors) {
        if (sensors.isNotEmpty && ref.read(selectedSensorIdsProvider).isEmpty) {
          ref.read(selectedSensorIdsProvider.notifier).state = {sensors.first.id};
        }
      });
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GroupFilterPanel(
            workshopsAsync: workshopsAsync,
            sitesAsync: sitesAsync,
            sensorsAsync: sensorsAsync,
            cachedWorkshops: cachedWorkshops,
            cachedSites: cachedSites,
            cachedSensors: cachedSensors,
            selectedSensorIds: selectedIds,
            selectedSiteId: siteId,
            selectedWorkshopId: workshopId,
            connectionIssue: connectionIssue,
            onWorkshopChanged: (id) {
              ref.read(workshopFilterProvider.notifier).state = id;
              ref.read(siteFilterProvider.notifier).state = null;
              ref.read(selectedSensorIdsProvider.notifier).state = {};
            },
            onSiteChanged: (id) {
              ref.read(siteFilterProvider.notifier).state = id;
              ref.read(selectedSensorIdsProvider.notifier).state = {};
            },
            onSensorToggle: (sensorId, selected) {
              final current = {...ref.read(selectedSensorIdsProvider)};
              if (selected) {
                current.add(sensorId);
              } else {
                current.remove(sensorId);
              }
              ref.read(selectedSensorIdsProvider.notifier).state = current;
            },
          ),
          const SizedBox(height: 12),
          _TimeControlBar(
            preset: preset,
            presetSelected: isLiveWindow && liveSpan == null && customRange == null,
            hasCustom: !isLiveWindow && customRange != null,
            scale: scale,
            onPreset: (value) {
              ref.read(timeRangePresetProvider.notifier).state = value;
              ref.read(chartScaleProvider.notifier).state =
                  defaultChartScaleForPreset(value);
              setLiveChartWindow(ref);
            },
            onScale: (value) => ref.read(chartScaleProvider.notifier).state = value,
            onCustom: () => _pickCustomRange(context),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildChartArea(
                  theme: theme,
                  readingsAsync: readingsAsync,
                  cachedReadings: cachedReadings,
                  scale: scale,
                  range: range,
                  connectionIssue: connectionIssue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea({
    required ThemeData theme,
    required AsyncValue readingsAsync,
    required GroupedReadingsResponse? cachedReadings,
    required ChartScale scale,
    required TimeRange range,
    required String? connectionIssue,
  }) {
    return readingsAsync.when(
      loading: () {
        if (cachedReadings != null) {
          return _chartContent(
            theme: theme,
            response: cachedReadings,
            scale: scale,
            range: range,
            connectionIssue: connectionIssue,
            isStale: true,
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, _) {
        if (cachedReadings != null) {
          return _chartContent(
            theme: theme,
            response: cachedReadings,
            scale: scale,
            range: range,
            connectionIssue: connectionIssue ?? friendlyApiError(error),
            isStale: true,
          );
        }
        return _MessagePanel(
          icon: Icons.error_outline,
          title: 'Не удалось загрузить данные',
          subtitle: friendlyApiError(error),
          color: theme.colorScheme.error,
        );
      },
      data: (response) => _chartContent(
        theme: theme,
        response: response,
        scale: scale,
        range: range,
        connectionIssue: connectionIssue,
        isStale: false,
      ),
    );
  }

  Widget _chartContent({
    required ThemeData theme,
    required GroupedReadingsResponse response,
    required ChartScale scale,
    required TimeRange range,
    required String? connectionIssue,
    required bool isStale,
  }) {
    final chartSeries =
        response.series.where((s) => s.points.isNotEmpty).toList();
    if (chartSeries.isEmpty) {
      return _MessagePanel(
        icon: Icons.show_chart,
        title: 'Нет данных за выбранный период',
        subtitle:
            'Выберите датчик или группу и убедитесь, что телеметрия поступает.',
        color: theme.colorScheme.secondary,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ток фазы · $pointsCount точек · ${chartSeries.length} ряд(ов)',
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (isStale || connectionIssue != null)
              Chip(
                avatar: const Icon(Icons.cloud_off, size: 16),
                label: const Text('offline'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: CurrentChart(
            key: ValueKey(
              '${range.end.millisecondsSinceEpoch}_'
              '${latestPointTime?.millisecondsSinceEpoch ?? 0}_$pointsCount',
            ),
            series: [
              for (var i = 0; i < chartSeries.length; i++)
                ChartSeriesData(
                  sensorId: chartSeries[i].sensorId,
                  sensorName: chartSeries[i].sensorName,
                  points: chartSeries[i].points,
                  color: CurrentChart.colorForIndex(i),
                ),
            ],
            scale: scale,
            rangeStart: range.start,
            rangeEnd: range.end,
            onVisibleRangeChanged: (start, end) {
              final span = end.difference(start);
              final isLive = end.isAfter(
                DateTime.now().subtract(const Duration(minutes: 2)),
              );
              ref.read(chartScaleProvider.notifier).state =
                  chartScaleForVisibleSpan(span);
              if (isLive) {
                setLiveChartWindow(ref, span: span);
              } else {
                setHistoricalChartWindow(
                  ref,
                  TimeRange(start: start, end: end),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final custom = ref.read(customTimeRangeProvider);
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
      helpText: 'Произвольный диапазон',
    );
    if (picked != null) {
      setHistoricalChartWindow(
        ref,
        TimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
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
      ref.read(chartScaleProvider.notifier).state = chartScaleForVisibleSpan(span);
    }
  }
}

class _TimeControlBar extends StatelessWidget {
  const _TimeControlBar({
    required this.preset,
    required this.presetSelected,
    required this.hasCustom,
    required this.scale,
    required this.onPreset,
    required this.onScale,
    required this.onCustom,
  });

  final TimeRangePreset preset;
  final bool presetSelected;
  final bool hasCustom;
  final ChartScale scale;
  final ValueChanged<TimeRangePreset> onPreset;
  final ValueChanged<ChartScale> onScale;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Период:', style: theme.textTheme.bodyMedium),
            for (final p in TimeRangePreset.values)
              ChoiceChip(
                label: Text(p.label),
                selected: presetSelected && preset == p,
                onSelected: (_) => onPreset(p),
              ),
            ActionChip(
              label: const Text('Свой'),
              avatar: const Icon(Icons.date_range, size: 18),
              onPressed: onCustom,
            ),
            const SizedBox(width: 8),
            Text('Детализация:', style: theme.textTheme.bodyMedium),
            for (final s in ChartScale.values)
              ChoiceChip(
                label: Text(s.label),
                selected: scale == s,
                onSelected: (_) => onScale(s),
              ),
          ],
        ),
      ],
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
