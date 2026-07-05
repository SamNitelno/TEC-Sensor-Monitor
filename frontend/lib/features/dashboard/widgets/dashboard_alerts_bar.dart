import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
import 'package:tek_sensor_monitor/models/downtime.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

/// Status strip above the chart grid — pushes layout instead of compressing charts.
class DashboardAlertsBar extends ConsumerWidget {
  const DashboardAlertsBar({
    super.key,
    this.connectionIssue,
  });

  final String? connectionIssue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final sensorsAsync = ref.watch(sensorsProvider);
    final panels = ref.watch(chartPanelsProvider);

    final offlineSensors = sensorsAsync.valueOrNull
            ?.where((s) => s.status == 'offline')
            .toList() ??
        const <Sensor>[];

    final openEvents = <DowntimeEvent>[];
    for (final panel in panels) {
      final events = ref.watch(panelDowntimeEventsProvider(panel.id)).valueOrNull;
      if (events != null) {
        openEvents.addAll(events.where((e) => e.isOpen));
      }
    }

    final hasAlerts = connectionIssue != null ||
        offlineSensors.isNotEmpty ||
        openEvents.isNotEmpty;

    if (!hasAlerts) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (connectionIssue != null)
                _AlertChip(
                  icon: Icons.cloud_off,
                  label: connectionIssue!,
                  color: theme.colorScheme.error,
                ),
              for (final sensor in offlineSensors)
                _AlertChip(
                  icon: Icons.sensors_off,
                  label: l10n.downtimeOfflineChip(sensor.name),
                  color: theme.colorScheme.error,
                ),
              for (final event in openEvents)
                _AlertChip(
                  icon: event.isOffline
                      ? Icons.cloud_off
                      : Icons.pause_circle_outline,
                  label: event.isOffline
                      ? l10n.downtimeOfflineChip(event.sensorName)
                      : l10n.downtimeIdleChip(event.sensorName),
                  color: event.isOffline
                      ? theme.colorScheme.error
                      : theme.colorScheme.tertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
