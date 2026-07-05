import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

Future<void> showSensorInfoDialog(
  BuildContext context,
  WidgetRef ref,
  Sensor sensor,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _SensorInfoDialog(sensorId: sensor.id),
  );
}

class _SensorInfoDialog extends ConsumerStatefulWidget {
  const _SensorInfoDialog({required this.sensorId});

  final int sensorId;

  @override
  ConsumerState<_SensorInfoDialog> createState() => _SensorInfoDialogState();
}

class _SensorInfoDialogState extends ConsumerState<_SensorInfoDialog> {
  SensorAuditInfo? _audit;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final audit =
          await ref.read(apiClientProvider).fetchSensorAudit(widget.sensorId);
      if (mounted) {
        setState(() {
          _audit = audit;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return AlertDialog(
      title: Text(l10n.sensorInfoTitle),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: TekLoadingIndicator())
            : _error != null
                ? Text(friendlyApiError(_error!, l10n))
                : _audit == null
                    ? Text(l10n.noData)
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_audit!.name} (${_audit!.deviceId})'),
                            if (_audit!.color != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundColor:
                                        parseHexColor(_audit!.color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(l10n.colorValue(_audit!.color!)),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              l10n.createdAt(
                                fmt.format(_audit!.createdAt.toLocal()),
                                _audit!.createdByLogin != null
                                    ? ' · ${_audit!.createdByLogin}'
                                    : '',
                              ),
                            ),
                            Text(
                              l10n.currentPlacement(
                                _audit!.currentWorkshopName ?? '—',
                                _audit!.currentSiteName != null
                                    ? ' / ${_audit!.currentSiteName}'
                                    : '',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.placementHistoryTitle,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            if (_audit!.placementHistory.isEmpty)
                              Text(l10n.placementHistoryEmpty)
                            else
                              for (final record in _audit!.placementHistory)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${fmt.format(record.assignedAt.toLocal())}: '
                                    '${record.workshopName ?? '—'}'
                                    '${record.siteName != null ? ' / ${record.siteName}' : ''}'
                                    '${record.assignedByLogin != null ? ' · ${record.assignedByLogin}' : ''}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                          ],
                        ),
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
