import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/app_shell.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/widgets/tek_sort_dropdown.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/groups/groups_screen.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_platform.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';
import 'package:tek_sensor_monitor/features/sensors/sensor_info_dialog.dart';
import 'package:tek_sensor_monitor/models/site.dart';
import 'package:tek_sensor_monitor/widgets/color_picker_field.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

enum _SensorsSortField { name, site, createdAt }

class SensorsScreen extends ConsumerStatefulWidget {
  const SensorsScreen({super.key});

  @override
  ConsumerState<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends ConsumerState<SensorsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _SensorsSortField _sortField = _SensorsSortField.name;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _siteName(Sensor sensor, List<Site> sites) {
    if (sensor.siteId == null) return '';
    for (final site in sites) {
      if (site.id == sensor.siteId) return site.name;
    }
    return '';
  }

  List<Sensor> _filterSensors(List<Sensor> sensors, List<Site> sites) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return sensors;
    return sensors.where((sensor) {
      final siteName = _siteName(sensor, sites);
      final haystack = [
        sensor.name,
        sensor.deviceId,
        sensor.status,
        siteName,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  List<Sensor> _sortSensors(List<Sensor> sensors, List<Site> sites) {
    final sorted = [...sensors];
    sorted.sort((a, b) {
      final int cmp;
      switch (_sortField) {
        case _SensorsSortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SensorsSortField.site:
          cmp = _siteName(a, sites)
              .toLowerCase()
              .compareTo(_siteName(b, sites).toLowerCase());
          if (cmp != 0) break;
          return _sortAscending
              ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
              : b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case _SensorsSortField.createdAt:
          cmp = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  Future<void> _setAllNotifications(bool enabled) async {
    final l10n = context.l10n;
    try {
      await ref.read(apiClientProvider).setAllSensorNotifications(enabled: enabled);
      ref.invalidate(sensorsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? l10n.notificationsEnabledAllSensors
                  : l10n.notificationsDisabledAllSensors,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sensorsAsync = ref.watch(sensorsProvider);
    final sitesAsync = ref.watch(allSitesProvider);
    final sites = sitesAsync.valueOrNull ?? [];

    return sensorsAsync.when(
      loading: () => const TekPageLoading(),
      error: (e, _) => Center(child: Text(friendlyApiError(e, l10n))),
      data: (sensors) {
        final filtered = _sortSensors(_filterSensors(sensors, sites), sites);
        final allEnabled =
            sensors.isNotEmpty && sensors.every((s) => s.notificationsEnabled);

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SearchBar(
                  controller: _searchController,
                  hintText: l10n.searchSensorsHint,
                  leading: const Icon(Icons.search),
                  trailing: _query.isEmpty
                      ? null
                      : [
                          IconButton(
                            tooltip: l10n.clear,
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                        ],
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    TekSortDropdown<_SensorsSortField>(
                      value: _sortField,
                      items: [
                        DropdownMenuItem(
                          value: _SensorsSortField.name,
                          child: Text(l10n.sortAlphabetical),
                        ),
                        DropdownMenuItem(
                          value: _SensorsSortField.site,
                          child: Text(l10n.sortBySite),
                        ),
                        DropdownMenuItem(
                          value: _SensorsSortField.createdAt,
                          child: Text(l10n.sortByCreatedAt),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sortField = value);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: _sortAscending
                          ? l10n.sortAscending
                          : l10n.sortDescending,
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                      ),
                      onPressed: () =>
                          setState(() => _sortAscending = !_sortAscending),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: allEnabled
                          ? l10n.disableNotificationsAll
                          : l10n.enableNotificationsAll,
                      icon: Icon(
                        allEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off_outlined,
                      ),
                      onPressed: () => _setAllNotifications(!allEnabled),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final sensor = filtered[index];
                    final siteName = _siteName(sensor, sites);
                    final itemL10n = context.l10n;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 8,
                          backgroundColor: resolveSensorChipColor(sensor, index),
                        ),
                        title: Text(sensor.name),
                        subtitle: Text(
                          [
                            sensor.deviceId,
                            sensor.isOnline ? 'online' : 'offline',
                            if (siteName.isNotEmpty) siteName,
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: sensor.notificationsEnabled
                                  ? itemL10n.disableNotifications
                                  : itemL10n.enableNotifications,
                              icon: Icon(
                                sensor.notificationsEnabled
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_off_outlined,
                                size: 20,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                await ref.read(apiClientProvider).updateSensor(
                                      sensor.id,
                                      notificationsEnabled:
                                          !sensor.notificationsEnabled,
                                    );
                                ref.invalidate(sensorsProvider);
                              },
                            ),
                            IconButton(
                              tooltip: itemL10n.info,
                              icon: const Icon(Icons.info_outline, size: 20),
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  showSensorInfoDialog(context, ref, sensor),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await _editSensor(
                                    context,
                                    ref,
                                    sensor,
                                    sites,
                                  );
                                } else if (action == 'delete') {
                                  await _deleteSensor(context, ref, sensor);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(itemL10n.edit),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(itemL10n.delete),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isBleProvisioningSupported)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FloatingActionButton.extended(
                    heroTag: 'ble',
                    onPressed: () => context.push('/provisioning'),
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('BLE'),
                  ),
                ),
              FloatingActionButton.extended(
                heroTag: 'add',
                onPressed: () => _createSensor(context, ref, sites),
                icon: const Icon(Icons.add),
                label: Text(l10n.sensorFab),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createSensor(
    BuildContext context,
    WidgetRef ref,
    List<Site> sites,
  ) async {
    final nameController = TextEditingController();
    final deviceIdController = TextEditingController();
    int? siteId;
    String? color;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = context.l10n;
          return AlertDialog(
          title: Text(l10n.newSensorTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: l10n.name),
                ),
                TextField(
                  controller: deviceIdController,
                  decoration: const InputDecoration(labelText: 'Device ID'),
                ),
                if (sites.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    value: siteId,
                    decoration: InputDecoration(labelText: l10n.siteLabel),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.noSite),
                      ),
                      ...sites.map(
                        (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ),
                    ],
                    onChanged: (value) => setState(() => siteId = value),
                  ),
                const SizedBox(height: 12),
                ColorPickerField(
                  label: l10n.chartColorLabel,
                  value: color,
                  onChanged: (value) => setState(() => color = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.create),
            ),
          ],
        );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result = await ref.read(apiClientProvider).createSensor(
            name: nameController.text.trim(),
            deviceId: deviceIdController.text.trim(),
            siteId: siteId,
            color: color,
          );
      ref.invalidate(sensorsProvider);
      if (context.mounted) {
        await _showTokenDialog(context, result);
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    }
  }

  Future<void> _editSensor(
    BuildContext context,
    WidgetRef ref,
    Sensor sensor,
    List<Site> sites,
  ) async {
    final nameController = TextEditingController(text: sensor.name);
    final idlePowerController = TextEditingController(
      text: sensor.idlePowerThresholdW?.toString() ?? '',
    );
    final idleCurrentController = TextEditingController(
      text: sensor.idleCurrentThresholdA?.toString() ?? '',
    );
    final idleDurationController = TextEditingController(
      text: sensor.idleDurationSeconds?.toString() ?? '',
    );
    int? siteId = sensor.siteId;
    String? color = sensor.color;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = context.l10n;
          return AlertDialog(
          title: Text(l10n.editSensorTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: l10n.name),
                ),
                if (sites.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    value: siteId,
                    decoration: InputDecoration(labelText: l10n.siteLabel),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.noSite),
                      ),
                      ...sites.map(
                        (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ),
                    ],
                    onChanged: (value) => setState(() => siteId = value),
                  ),
                const SizedBox(height: 12),
                ColorPickerField(
                  label: l10n.chartColorLabel,
                  value: color,
                  onChanged: (value) => setState(() => color = value),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.idleDetectionTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextField(
                  controller: idlePowerController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.idlePowerThresholdLabel,
                  ),
                ),
                TextField(
                  controller: idleCurrentController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.idleCurrentThresholdLabel,
                  ),
                ),
                TextField(
                  controller: idleDurationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.idleDurationLabel,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      double? parseDouble(String raw) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return null;
        return double.tryParse(trimmed.replaceAll(',', '.'));
      }

      int? parseInt(String raw) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return null;
        return int.tryParse(trimmed);
      }

      final idlePower = parseDouble(idlePowerController.text);
      final idleCurrent = parseDouble(idleCurrentController.text);
      final idleDuration = parseInt(idleDurationController.text);

      await ref.read(apiClientProvider).updateSensor(
            sensor.id,
            name: nameController.text.trim(),
            siteId: siteId,
            clearSite: siteId == null,
            color: color,
            clearColor: color == null,
            idlePowerThresholdW: idlePower,
            clearIdlePowerThreshold: idlePowerController.text.trim().isEmpty,
            idleCurrentThresholdA: idleCurrent,
            clearIdleCurrentThreshold: idleCurrentController.text.trim().isEmpty,
            idleDurationSeconds: idleDuration,
            clearIdleDuration: idleDurationController.text.trim().isEmpty,
          );
      ref.invalidate(sensorsProvider);
    } catch (e) {
      if (context.mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    }
  }

  Future<void> _deleteSensor(
    BuildContext context,
    WidgetRef ref,
    Sensor sensor,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
        title: Text(l10n.deleteSensorTitle),
        content: Text(sensor.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      );
      },
    );
    if (confirmed != true) return;
    await ref.read(apiClientProvider).deleteSensor(sensor.id);
    ref.invalidate(sensorsProvider);
  }

  Future<void> _showTokenDialog(
    BuildContext context,
    SensorCreateResult result,
  ) {
    return showDialog(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
        title: Text(l10n.sensorCreatedTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                result.warning,
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
              const SizedBox(height: 12),
              SelectableText('Token:\n${result.apiToken}'),
              const SizedBox(height: 12),
              SelectableText(result.integration.copyText),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => copyToClipboard(
              context,
              result.apiToken,
              message: l10n.tokenCopied,
            ),
            child: Text(l10n.copyToken),
          ),
          TextButton(
            onPressed: () => copyToClipboard(
              context,
              result.integration.copyText,
              message: l10n.snippetCopied,
            ),
            child: Text(l10n.copySnippet),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.done),
          ),
        ],
      );
      },
    );
  }
}
