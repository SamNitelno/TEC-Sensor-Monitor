import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/current_chart.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/group_filter_panel.dart';

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
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidate(readingsProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sensorsAsync = ref.watch(sensorsProvider);
    final sitesAsync = ref.watch(sitesProvider);
    final workshopsAsync = ref.watch(workshopsProvider);
    final selectedIds = ref.watch(selectedSensorIdsProvider);
    final siteId = ref.watch(siteFilterProvider);
    final workshopId = ref.watch(workshopFilterProvider);
    final preset = ref.watch(timeRangePresetProvider);
    final customRange = ref.watch(customTimeRangeProvider);
    final scale = ref.watch(chartScaleProvider);
    final readingsAsync = ref.watch(readingsProvider);

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
            sitesAsync: sitesAsync,
            workshopsAsync: workshopsAsync,
            sensorsAsync: sensorsAsync,
            selectedSensorIds: selectedIds,
            selectedSiteId: siteId,
            selectedWorkshopId: workshopId,
            onSiteChanged: (siteId) {
              ref.read(siteFilterProvider.notifier).state = siteId;
              ref.read(workshopFilterProvider.notifier).state = null;
              ref.read(selectedSensorIdsProvider.notifier).state = {};
            },
            onWorkshopChanged: (workshopId) {
              ref.read(workshopFilterProvider.notifier).state = workshopId;
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
          _RangePresetBar(
            selected: preset,
            hasCustom: customRange != null,
            onPreset: (value) {
              ref.read(customTimeRangeProvider.notifier).state = null;
              ref.read(timeRangePresetProvider.notifier).state = value;
            },
            onCustom: () => _pickCustomRange(context),
          ),
          const SizedBox(height: 12),
          _ScaleBar(
            selected: scale,
            onChanged: (value) =>
                ref.read(chartScaleProvider.notifier).state = value,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: readingsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _MessagePanel(
                    icon: Icons.error_outline,
                    title: 'Не удалось загрузить данные',
                    subtitle: error.toString(),
                    color: theme.colorScheme.error,
                  ),
                  data: (response) {
                    final chartSeries = response.series
                        .where((s) => s.points.isNotEmpty)
                        .toList();
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
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ток фазы · $pointsCount точек · ${chartSeries.length} ряд(ов)',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: CurrentChart(
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
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
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
      ref.read(customTimeRangeProvider.notifier).state = TimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        ),
      );
    }
  }
}

class _RangePresetBar extends StatelessWidget {
  const _RangePresetBar({
    required this.selected,
    required this.hasCustom,
    required this.onPreset,
    required this.onCustom,
  });

  final TimeRangePreset selected;
  final bool hasCustom;
  final ValueChanged<TimeRangePreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in TimeRangePreset.values)
          ChoiceChip(
            label: Text(preset.label),
            selected: !hasCustom && selected == preset,
            onSelected: (_) => onPreset(preset),
          ),
        ActionChip(
          label: const Text('Свой'),
          avatar: const Icon(Icons.date_range, size: 18),
          onPressed: onCustom,
        ),
      ],
    );
  }
}

class _ScaleBar extends StatelessWidget {
  const _ScaleBar({
    required this.selected,
    required this.onChanged,
  });

  final ChartScale selected;
  final ValueChanged<ChartScale> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Text('Масштаб:', style: Theme.of(context).textTheme.bodyMedium),
        for (final scale in ChartScale.values)
          ChoiceChip(
            label: Text(scale.label),
            selected: selected == scale,
            onSelected: (_) => onChanged(scale),
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
            Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
