import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';
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
    required this.allSensorsSelected,
    required this.selectedWorkshopIds,
    required this.selectedSiteIds,
    required this.onWorkshopsAll,
    required this.onWorkshopToggle,
    required this.onSitesAll,
    required this.onSiteToggle,
    required this.onAllSensors,
    required this.onSensorToggle,
    this.connectionIssue,
    this.embedded = false,
  });

  final AsyncValue<List<Workshop>> workshopsAsync;
  final AsyncValue<List<Site>> sitesAsync;
  final AsyncValue<List<Sensor>> sensorsAsync;
  final List<Workshop>? cachedWorkshops;
  final List<Site>? cachedSites;
  final List<Sensor>? cachedSensors;
  final Set<int> selectedSensorIds;
  final bool allSensorsSelected;
  final Set<int> selectedWorkshopIds;
  final Set<int> selectedSiteIds;
  final VoidCallback onWorkshopsAll;
  final void Function(int workshopId, bool selected) onWorkshopToggle;
  final VoidCallback onSitesAll;
  final void Function(int siteId, bool selected) onSiteToggle;
  final VoidCallback onAllSensors;
  final void Function(int sensorId, bool selected) onSensorToggle;
  final String? connectionIssue;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded)
          Text('Группировка', style: Theme.of(context).textTheme.labelLarge),
        if (connectionIssue != null) ...[
          if (!embedded) const SizedBox(height: 8),
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
        SizedBox(height: embedded ? 4 : 8),
        _buildWorkshops(context),
        SizedBox(height: embedded ? 4 : 8),
        _buildSites(context),
        SizedBox(height: embedded ? 4 : 8),
        _buildSensors(context),
      ],
    );

    if (embedded) {
      return content;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: content,
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
    final allActive = selectedWorkshopIds.isEmpty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _allScopeChip(
          context: context,
          label: 'Все цеха',
          active: allActive,
          onPressed: onWorkshopsAll,
        ),
        for (final workshop in workshops)
          FilterChip(
            avatar: CircleAvatar(
              radius: 6,
              backgroundColor: resolveWorkshopChipColor(
                workshop,
                workshops.indexOf(workshop),
              ),
            ),
            label: Text(workshop.name),
            selected: selectedWorkshopIds.contains(workshop.id),
            showCheckmark: true,
            onSelected: (selected) => onWorkshopToggle(workshop.id, selected),
          ),
      ],
    );
  }

  Widget _buildSites(BuildContext context) {
    return sitesAsync.when(
      loading: () => cachedSites != null
          ? _siteChips(context, cachedSites!)
          : const LinearProgressIndicator(),
      error: (e, _) => cachedSites != null
          ? _siteChips(context, cachedSites!)
          : _inlineError('Площадки: ${friendlyApiError(e)}'),
      data: (sites) {
        if (sites.isEmpty) {
          return const Text('Нет площадок в выбранной группе');
        }
        return _siteChips(context, sites);
      },
    );
  }

  Widget _siteChips(BuildContext context, List<Site> sites) {
    final allActive = selectedSiteIds.isEmpty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _allScopeChip(
          context: context,
          label: 'Все площадки',
          active: allActive,
          onPressed: onSitesAll,
        ),
        for (final site in sites)
          FilterChip(
            avatar: CircleAvatar(
              radius: 6,
              backgroundColor: resolveSiteChipColor(site, sites.indexOf(site)),
            ),
            label: Text(site.name),
            selected: selectedSiteIds.contains(site.id),
            showCheckmark: true,
            onSelected: (selected) => onSiteToggle(site.id, selected),
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
        _allScopeChip(
          context: context,
          label: 'Все датчики',
          active: allSensorsSelected,
          onPressed: onAllSensors,
        ),
        for (final sensor in sensors)
          FilterChip(
            avatar: Icon(
              Icons.circle,
              size: 10,
              color: selectedSiteIds.isNotEmpty
                  ? resolveSensorChipColor(sensor, sensors.indexOf(sensor))
                  : (sensor.isOnline ? Colors.green : Colors.grey),
            ),
            label: Text(
              sensor.isOnline ? sensor.name : '${sensor.name} · offline',
            ),
            selected: !allSensorsSelected && selectedSensorIds.contains(sensor.id),
            showCheckmark: true,
            onSelected: (selected) => onSensorToggle(sensor.id, selected),
          ),
      ],
    );
  }

  Widget _allScopeChip({
    required BuildContext context,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Opacity(
      opacity: active ? 1 : 0.45,
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onPressed(),
      ),
    );
  }

  Widget _inlineError(String message) {
    return Text(message, style: const TextStyle(fontSize: 13));
  }
}
