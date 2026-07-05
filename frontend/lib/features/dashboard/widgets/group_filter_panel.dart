import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
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
    required this.allSitesForFilter,
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
  /// Full site list for client-side sensor filtering by workshop.
  final List<Site> allSitesForFilter;
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

  List<Site> _visibleSites(List<Site> sites) =>
      filterSitesForPanel(sites, selectedWorkshopIds);

  List<Sensor> _visibleSensors(List<Sensor> sensors) =>
      filterSensorsForPanel(
        sensors,
        allSitesForFilter,
        selectedSiteIds,
        selectedWorkshopIds,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded)
          Text(l10n.groupingLabel, style: Theme.of(context).textTheme.labelSmall),
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
    final l10n = context.l10n;
    return workshopsAsync.when(
      loading: () => cachedWorkshops != null
          ? _workshopChips(context, cachedWorkshops!)
          : const LinearProgressIndicator(),
      error: (e, _) => cachedWorkshops != null
          ? _workshopChips(context, cachedWorkshops!)
          : _inlineError(context, l10n.workshopsLoadError(friendlyApiError(e, l10n))),
      data: (workshops) => _workshopChips(context, workshops),
    );
  }

  Widget _workshopChips(BuildContext context, List<Workshop> workshops) {
    final l10n = context.l10n;
    final allActive = selectedWorkshopIds.isEmpty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _allScopeChip(
          context: context,
          label: Text(l10n.allWorkshops),
          active: allActive,
          onPressed: onWorkshopsAll,
        ),
        for (final workshop in workshops)
          _filterChip(
            context: context,
            avatar: CircleAvatar(
              radius: 6,
              backgroundColor: resolveWorkshopChipColor(
                workshop,
                workshops.indexOf(workshop),
              ),
            ),
            label: Text(workshop.name),
            selected: selectedWorkshopIds.contains(workshop.id),
            onSelected: (selected) => onWorkshopToggle(workshop.id, selected),
          ),
      ],
    );
  }

  Widget _buildSites(BuildContext context) {
    final l10n = context.l10n;
    return sitesAsync.when(
      loading: () {
        final fallback = cachedSites ?? allSitesForFilter;
        final visible = _visibleSites(fallback);
        if (visible.isEmpty && selectedWorkshopIds.isNotEmpty) {
          return Text(l10n.noSitesInGroup);
        }
        return visible.isEmpty
            ? const LinearProgressIndicator()
            : _siteChips(context, visible);
      },
      error: (e, _) {
        final fallback = cachedSites ?? allSitesForFilter;
        final visible = _visibleSites(fallback);
        if (visible.isNotEmpty) {
          return _siteChips(context, visible);
        }
        return _inlineError(context, l10n.sitesLoadError(friendlyApiError(e, l10n)));
      },
      data: (sites) {
        final visible = _visibleSites(sites);
        if (visible.isEmpty) {
          return Text(l10n.noSitesInGroup);
        }
        return _siteChips(context, visible);
      },
    );
  }

  Widget _siteChips(BuildContext context, List<Site> sites) {
    final l10n = context.l10n;
    final allActive = selectedSiteIds.isEmpty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _allScopeChip(
          context: context,
          label: Text(l10n.allSites),
          active: allActive,
          onPressed: onSitesAll,
        ),
        for (final site in sites)
          _filterChip(
            context: context,
            avatar: CircleAvatar(
              radius: 6,
              backgroundColor: resolveSiteChipColor(site, sites.indexOf(site)),
            ),
            label: Text(site.name),
            selected: selectedSiteIds.contains(site.id),
            onSelected: (selected) => onSiteToggle(site.id, selected),
          ),
      ],
    );
  }

  Widget _buildSensors(BuildContext context) {
    final l10n = context.l10n;
    return sensorsAsync.when(
      loading: () {
        final fallback = cachedSensors ?? const <Sensor>[];
        final visible = _visibleSensors(fallback);
        if (visible.isEmpty && selectedWorkshopIds.isNotEmpty) {
          return Text(l10n.noSensorsInGroup);
        }
        return visible.isEmpty
            ? const LinearProgressIndicator()
            : _sensorChips(context, visible);
      },
      error: (e, _) {
        final fallback = cachedSensors ?? const <Sensor>[];
        final visible = _visibleSensors(fallback);
        if (visible.isNotEmpty) {
          return _sensorChips(context, visible);
        }
        return _inlineError(context, l10n.sensorsLoadError(friendlyApiError(e, l10n)));
      },
      data: (sensors) {
        final visible = _visibleSensors(sensors);
        if (visible.isEmpty) {
          return Text(l10n.noSensorsInGroup);
        }
        return _sensorChips(context, visible);
      },
    );
  }

  Widget _sensorChips(BuildContext context, List<Sensor> sensors) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _allScopeChip(
          context: context,
          label: Text(l10n.allSensors),
          active: allSensorsSelected,
          onPressed: onAllSensors,
        ),
        for (final sensor in sensors)
          _filterChip(
            context: context,
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
            selected:
                !allSensorsSelected && selectedSensorIds.contains(sensor.id),
            onSelected: (selected) => onSensorToggle(sensor.id, selected),
          ),
      ],
    );
  }

  Widget _filterChip({
    required BuildContext context,
    required Widget label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    Widget? avatar,
    bool showCheckmark = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      avatar: avatar,
      label: label,
      selected: selected,
      showCheckmark: showCheckmark,
      selectedColor: scheme.secondaryContainer,
      checkmarkColor: scheme.onSecondaryContainer,
      labelStyle: selected
          ? Theme.of(context).chipTheme.secondaryLabelStyle
          : Theme.of(context).chipTheme.labelStyle,
      onSelected: onSelected,
    );
  }

  Widget _allScopeChip({
    required BuildContext context,
    required Widget label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Opacity(
      opacity: active ? 1 : 0.45,
      child: _filterChip(
        context: context,
        label: label,
        selected: active,
        onSelected: (_) => onPressed(),
      ),
    );
  }

  Widget _inlineError(BuildContext context, String message) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
