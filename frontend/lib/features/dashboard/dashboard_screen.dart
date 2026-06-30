import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/current_chart.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

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
    final selectedId = ref.watch(selectedSensorIdProvider);
    final preset = ref.watch(timeRangePresetProvider);
    final customRange = ref.watch(customTimeRangeProvider);
    final scale = ref.watch(chartScaleProvider);
    final readingsAsync = ref.watch(readingsProvider);

    ref.listen(sensorsProvider, (previous, next) {
      next.whenData((sensors) {
        if (sensors.isNotEmpty && ref.read(selectedSensorIdProvider) == null) {
          ref.read(selectedSensorIdProvider.notifier).state = sensors.first.id;
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ТЭК · Мониторинг датчиков'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SensorSelector(
              sensorsAsync: sensorsAsync,
              selectedId: selectedId,
              onChanged: (id) =>
                  ref.read(selectedSensorIdProvider.notifier).state = id,
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
                      if (response.points.isEmpty) {
                        return _MessagePanel(
                          icon: Icons.show_chart,
                          title: 'Нет данных за выбранный период',
                          subtitle:
                              'Проверьте, что датчик отправляет телеметрию, и расширьте диапазон.',
                          color: theme.colorScheme.secondary,
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ток фазы · ${response.points.length} точек · bucket: ${response.bucket}',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: CurrentChart(
                              points: response.points,
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
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now,
      initialDateRange: () {
        final custom = ref.read(customTimeRangeProvider);
        if (custom != null) {
          return DateTimeRange(start: custom.start, end: custom.end);
        }
        return DateTimeRange(
          start: now.subtract(const Duration(days: 1)),
          end: now,
        );
      }(),
      helpText: 'Произвольный диапазон',
    );
    if (picked != null) {
      ref.read(customTimeRangeProvider.notifier).state = TimeRange(
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
      );
    }
  }
}

class _SensorSelector extends StatelessWidget {
  const _SensorSelector({
    required this.sensorsAsync,
    required this.selectedId,
    required this.onChanged,
  });

  final AsyncValue<List<Sensor>> sensorsAsync;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return sensorsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('Ошибка загрузки датчиков: $error'),
      data: (sensors) {
        if (sensors.isEmpty) {
          return const Text('Датчики не найдены. Запустите seed_test_sensor.py.');
        }
        return DropdownButtonFormField<int>(
          value: selectedId,
          decoration: const InputDecoration(
            labelText: 'Датчик',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: sensors
              .map(
                (sensor) => DropdownMenuItem(
                  value: sensor.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusDot(online: sensor.isOnline),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          sensor.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
      ),
    );
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
      crossAxisAlignment: WrapCrossAlignment.center,
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
