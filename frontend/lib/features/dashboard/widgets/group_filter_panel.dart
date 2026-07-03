import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/models/site.dart';

class GroupFilterPanel extends StatelessWidget {
  const GroupFilterPanel({
    super.key,
    required this.workshopsAsync,
    required this.sitesAsync,
    required this.sensorsAsync,
    required this.cachedWorkshops,
    required this.cachedSites,
    required this.cachedSensors,
    required this.selectedSensorIds,
    required this.selectedWorkshopId,
    required this.selectedSiteId,
    required this.onWorkshopChanged,
    required this.onSiteChanged,
    required this.onSensorToggle,
    this.connectionIssue,
  });

  final AsyncValue<List<Workshop>> workshopsAsync;
  final AsyncValue<List<Site>> sitesAsync;
  final AsyncValue<List<Sensor>> sensorsAsync;
  final List<Workshop>? cachedWorkshops;
  final List<Site>? cachedSites;
  final List<Sensor>? cachedSensors;
  final Set<int> selectedSensorIds;
  final int? selectedWorkshopId;
  final int? selectedSiteId;
  final ValueChanged<int?> onWorkshopChanged;
  final ValueChanged<int?> onSiteChanged;
  final void Function(int sensorId, bool selected) onSensorToggle;
  final String? connectionIssue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Группировка', style: Theme.of(context).textTheme.labelLarge),
            if (connectionIssue != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      connectionIssue!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _buildWorkshops(context),
            const SizedBox(height: 8),
            _buildSites(context),
            const SizedBox(height: 8),
            _buildSensors(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshops(BuildContext context) {
    return workshopsAsync.when(
      loading: () => cachedWorkshops != null
          ? _workshopChips(context, cachedWorkshops!)
          : const LinearProgressIndicator(),
      error: (e, _) => cachedWorkshops != null
          ? _workshopChips(context, cachedWorkshops!)
          : _inlineError('Цеха: ${friendlyApiError(e)}'),
      data: (workshops) => _workshopChips(context, workshops),
    );
  }

  Widget _workshopChips(BuildContext context, List<Workshop> workshops) {
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
  }

  Widget _buildSites(BuildContext context) {
    if (selectedWorkshopId == null) {
      return Text(
        'Выберите цех, чтобы отфильтровать площадки',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return sitesAsync.when(
      loading: () => cachedSites != null
          ? _siteChips(context, cachedSites!)
          : const LinearProgressIndicator(),
      error: (e, _) => cachedSites != null
          ? _siteChips(context, cachedSites!)
          : _inlineError('Площадки: ${friendlyApiError(e)}'),
      data: (sites) {
        if (sites.isEmpty) {
          return const Text('Нет площадок в выбранном цехе');
        }
        return _siteChips(context, sites);
      },
    );
  }

  Widget _siteChips(BuildContext context, List<Site> sites) {
    return Wrap(
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
    );
  }

  Widget _buildSensors(BuildContext context) {
    return sensorsAsync.when(
      loading: () => cachedSensors != null
          ? _sensorChips(context, cachedSensors!)
          : const LinearProgressIndicator(),
      error: (e, _) => cachedSensors != null
          ? _sensorChips(context, cachedSensors!)
          : _inlineError('Датчики: ${friendlyApiError(e)}'),
      data: (sensors) {
        if (sensors.isEmpty) {
          return const Text('Нет датчиков в выбранной группе');
        }
        return _sensorChips(context, sensors);
      },
    );
  }

  Widget _sensorChips(BuildContext context, List<Sensor> sensors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final sensor in sensors)
          FilterChip(
            avatar: Icon(
              Icons.circle,
              size: 10,
              color: sensor.isOnline ? Colors.green : Colors.grey,
            ),
            label: Text(
              sensor.isOnline ? sensor.name : '${sensor.name} · offline',
            ),
            selected: selectedSensorIds.contains(sensor.id),
            onSelected: (selected) => onSensorToggle(sensor.id, selected),
          ),
      ],
    );
  }

  Widget _inlineError(String message) {
    return Text(message, style: const TextStyle(fontSize: 13));
  }
}
