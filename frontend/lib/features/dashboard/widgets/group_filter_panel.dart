import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/models/site.dart';

class GroupFilterPanel extends StatelessWidget {
  const GroupFilterPanel({
    super.key,
    required this.sitesAsync,
    required this.workshopsAsync,
    required this.sensorsAsync,
    required this.selectedSensorIds,
    required this.selectedSiteId,
    required this.selectedWorkshopId,
    required this.onSiteChanged,
    required this.onWorkshopChanged,
    required this.onSensorToggle,
  });

  final AsyncValue<List<Site>> sitesAsync;
  final AsyncValue<List<Workshop>> workshopsAsync;
  final AsyncValue<List<Sensor>> sensorsAsync;
  final Set<int> selectedSensorIds;
  final int? selectedSiteId;
  final int? selectedWorkshopId;
  final ValueChanged<int?> onSiteChanged;
  final ValueChanged<int?> onWorkshopChanged;
  final void Function(int sensorId, bool selected) onSensorToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Группировка', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            sitesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Ошибка площадок: $e'),
              data: (sites) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Все площадки'),
                    selected: selectedSiteId == null,
                    onSelected: (_) => onSiteChanged(null),
                  ),
                  for (final site in sites)
                    FilterChip(
                      label: Text(site.name),
                      selected: selectedSiteId == site.id,
                      onSelected: (_) => onSiteChanged(site.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            workshopsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('Ошибка цехов: $e'),
              data: (workshops) {
                if (workshops.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Все цеха'),
                      selected: selectedWorkshopId == null,
                      onSelected: (_) => onWorkshopChanged(null),
                    ),
                    for (final workshop in workshops)
                      FilterChip(
                        label: Text(workshop.name),
                        selected: selectedWorkshopId == workshop.id,
                        onSelected: (_) => onWorkshopChanged(workshop.id),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            sensorsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Ошибка датчиков: $e'),
              data: (sensors) {
                if (sensors.isEmpty) {
                  return const Text('Нет датчиков в выбранной группе');
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sensor in sensors)
                      FilterChip(
                        label: Text(sensor.name),
                        selected: selectedSensorIds.contains(sensor.id),
                        onSelected: (selected) => onSensorToggle(sensor.id, selected),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
