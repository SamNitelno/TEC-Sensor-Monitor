import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

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
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return AlertDialog(
      title: const Text('Информация о датчике'),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Text(friendlyApiError(_error!))
                : _audit == null
                    ? const Text('Нет данных')
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
                                  Text('Цвет: ${_audit!.color}'),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'Создан: ${fmt.format(_audit!.createdAt.toLocal())}'
                              '${_audit!.createdByLogin != null ? ' · ${_audit!.createdByLogin}' : ''}',
                            ),
                            Text(
                              'Текущее размещение: '
                              '${_audit!.currentWorkshopName ?? '—'}'
                              '${_audit!.currentSiteName != null ? ' / ${_audit!.currentSiteName}' : ''}',
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'История размещения',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            if (_audit!.placementHistory.isEmpty)
                              const Text('История пуста')
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
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
