import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tek_sensor_monitor/core/app_shell.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_platform.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

import 'package:tek_sensor_monitor/models/site.dart';

class SensorsScreen extends ConsumerWidget {
  const SensorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorsAsync = ref.watch(sensorsProvider);
    final workshopsAsync = ref.watch(workshopsProvider);

    return sensorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (sensors) => Scaffold(
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sensors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final sensor = sensors[index];
            return Card(
              child: ListTile(
                title: Text(sensor.name),
                subtitle: Text(
                  '${sensor.deviceId} · ${sensor.isOnline ? "online" : "offline"}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editSensor(context, ref, sensor, workshopsAsync.valueOrNull ?? []);
                    } else if (action == 'delete') {
                      await _deleteSensor(context, ref, sensor);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Изменить')),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
              ),
            );
          },
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
              onPressed: () => _createSensor(context, ref, workshopsAsync.valueOrNull ?? []),
              icon: const Icon(Icons.add),
              label: const Text('Датчик'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSensor(
    BuildContext context,
    WidgetRef ref,
    List<Workshop> workshops,
  ) async {
    final nameController = TextEditingController();
    final deviceIdController = TextEditingController();
    int? workshopId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый датчик'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: deviceIdController,
              decoration: const InputDecoration(labelText: 'Device ID'),
            ),
            if (workshops.isNotEmpty)
              DropdownButtonFormField<int?>(
                value: workshopId,
                decoration: const InputDecoration(labelText: 'Цех'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Без цеха')),
                  ...workshops.map(
                    (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ),
                ],
                onChanged: (value) => workshopId = value,
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Создать')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result = await ref.read(apiClientProvider).createSensor(
            name: nameController.text.trim(),
            deviceId: deviceIdController.text.trim(),
            workshopId: workshopId,
          );
      ref.invalidate(sensorsProvider);
      if (context.mounted) {
        await _showTokenDialog(context, result);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _editSensor(
    BuildContext context,
    WidgetRef ref,
    Sensor sensor,
    List<Workshop> workshops,
  ) async {
    final nameController = TextEditingController(text: sensor.name);
    int? workshopId = sensor.workshopId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить датчик'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            if (workshops.isNotEmpty)
              DropdownButtonFormField<int?>(
                value: workshopId,
                decoration: const InputDecoration(labelText: 'Цех'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Без цеха')),
                  ...workshops.map(
                    (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ),
                ],
                onChanged: (value) => workshopId = value,
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(apiClientProvider).updateSensor(
            sensor.id,
            name: nameController.text.trim(),
            workshopId: workshopId,
            clearWorkshop: workshopId == null,
          );
      ref.invalidate(sensorsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _deleteSensor(BuildContext context, WidgetRef ref, Sensor sensor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить датчик?'),
        content: Text(sensor.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(apiClientProvider).deleteSensor(sensor.id);
    ref.invalidate(sensorsProvider);
  }

  Future<void> _showTokenDialog(BuildContext context, SensorCreateResult result) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Датчик создан'),
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
            onPressed: () => copyToClipboard(context, result.apiToken, message: 'Токен скопирован'),
            child: const Text('Копировать токен'),
          ),
          TextButton(
            onPressed: () => copyToClipboard(
              context,
              result.integration.copyText,
              message: 'Сниппет скопирован',
            ),
            child: const Text('Копировать сниппет'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}
