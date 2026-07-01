import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_constants.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_platform.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_provisioning_service.dart';
import 'package:tek_sensor_monitor/features/provisioning/provisioning_providers.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

enum ProvisioningStep { scan, configure, waiting, success }

class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  ProvisioningStep _step = ProvisioningStep.scan;
  final List<DiscoveredBleDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _scanning = false;
  String? _error;

  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();

  Sensor? _selectedSensor;
  String? _deviceToken;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = '${defaultApiBaseUrl.replaceAll(RegExp(r'/$'), '')}/api/v1/ingest';
    if (isBleProvisioningSupported) {
      _startScan();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scanSubscription?.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    _selectedDevice?.disconnect().catchError((_) {});
    ref.read(bleProvisioningServiceProvider).stopScan();
    super.dispose();
  }

  BleProvisioningService get _ble => ref.read(bleProvisioningServiceProvider);

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _devices.clear();
    });
    try {
      await _ble.stopScan();
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.provisioningServiceUuid)],
        timeout: const Duration(seconds: 15),
      );
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        final byId = <String, DiscoveredBleDevice>{};
        for (final result in results) {
          final id = result.device.remoteId.str;
          final name = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.advertisementData.advName;
          byId[id] = DiscoveredBleDevice(
            device: result.device,
            name: name.isNotEmpty ? name : id,
            rssi: result.rssi,
          );
        }
        setState(() {
          _devices
            ..clear()
            ..addAll(byId.values)
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
        });
      });
      await Future<void>.delayed(const Duration(seconds: 15));
      await _ble.stopScan();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _selectDevice(DiscoveredBleDevice item) async {
    setState(() {
      _error = null;
      _selectedDevice = item.device;
    });
    try {
      await _ble.connect(item.device);
      if (mounted) setState(() => _step = ProvisioningStep.configure);
    } catch (e) {
      setState(() => _error = 'Не удалось подключиться: $e');
    }
  }

  Future<void> _loadTokenForSensor(Sensor? sensor) async {
    if (sensor == null) {
      setState(() {
        _selectedSensor = null;
        _deviceToken = null;
      });
      return;
    }
    try {
      final creds = await ref.read(apiClientProvider).fetchProvisioningToken(sensor.id);
      setState(() {
        _selectedSensor = sensor;
        _deviceToken = creds.apiToken;
        _serverUrlController.text = creds.ingestUrl;
      });
    } catch (e) {
      setState(() => _error = 'Не удалось получить токен: $e');
    }
  }

  Future<void> _commitProvisioning() async {
    final device = _selectedDevice;
    final token = _deviceToken;
    final sensor = _selectedSensor;
    if (device == null || token == null || sensor == null) {
      setState(() => _error = 'Выберите ESP и зарегистрированный датчик');
      return;
    }
    if (_ssidController.text.trim().isEmpty) {
      setState(() => _error = 'Укажите SSID Wi-Fi');
      return;
    }

    setState(() {
      _error = null;
      _step = ProvisioningStep.waiting;
    });

    try {
      await _ble.provision(
        device: device,
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
        serverUrl: _serverUrlController.text.trim(),
        deviceToken: token,
      );
      await device.disconnect();
      _startOnlinePolling(sensor.id);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _step = ProvisioningStep.configure;
      });
    }
  }

  void _startOnlinePolling(int sensorId) {
    _pollAttempts = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _pollAttempts++;
      try {
        final sensor = await ref.read(apiClientProvider).fetchSensor(sensorId);
        if (sensor.isOnline && mounted) {
          timer.cancel();
          ref.invalidate(sensorsProvider);
          setState(() => _step = ProvisioningStep.success);
        } else if (_pollAttempts >= 45 && mounted) {
          timer.cancel();
          setState(() {
            _error =
                'Датчик не перешёл в online за 90 с. Проверьте Wi-Fi и URL сервера.';
            _step = ProvisioningStep.configure;
          });
        }
      } catch (_) {
        if (_pollAttempts >= 45) {
          timer.cancel();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isBleProvisioningSupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Привязка ESP по BLE')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              bleUnavailableWebMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Привязка ESP по BLE'),
        actions: [
          if (_step == ProvisioningStep.scan)
            IconButton(
              onPressed: _scanning ? null : _startScan,
              icon: const Icon(Icons.refresh),
              tooltip: 'Сканировать снова',
            ),
        ],
      ),
      body: switch (_step) {
        ProvisioningStep.scan => _buildScanStep(),
        ProvisioningStep.configure => _buildConfigureStep(),
        ProvisioningStep.waiting => _buildWaitingStep(),
        ProvisioningStep.success => _buildSuccessStep(),
      },
    );
  }

  Widget _buildScanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_scanning)
          const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Найдите ESP в режиме привязки (имя начинается с TEC-ESP). '
            'Убедитесь, что Bluetooth включён.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Expanded(
          child: _devices.isEmpty
              ? Center(
                  child: Text(_scanning ? 'Сканирование…' : 'Устройства не найдены'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _devices[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(item.name),
                        subtitle: Text('RSSI ${item.rssi} dBm'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectDevice(item),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildConfigureStep() {
    final sensorsAsync = ref.watch(sensorsProvider);

    return sensorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка загрузки датчиков: $e')),
      data: (sensors) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Подключено: ${_selectedDevice?.platformName.isNotEmpty == true ? _selectedDevice!.platformName : _selectedDevice?.remoteId.str}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'SSID Wi-Fi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль Wi-Fi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'URL приёма (ingest)',
                border: OutlineInputBorder(),
                helperText: 'POST /api/v1/ingest — LAN-IP, не localhost',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Sensor?>(
              value: _selectedSensor,
              decoration: const InputDecoration(
                labelText: 'Датчик в системе',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('— выберите —')),
                ...sensors.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text('${s.name} (${s.deviceId})'),
                  ),
                ),
              ],
              onChanged: _loadTokenForSensor,
            ),
            if (_deviceToken != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Токен загружен с сервера (${_deviceToken!.length} симв.)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _commitProvisioning,
              icon: const Icon(Icons.link),
              label: const Text('Записать и привязать'),
            ),
            TextButton(
              onPressed: () => setState(() => _step = ProvisioningStep.scan),
              child: const Text('Выбрать другое устройство'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingStep() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Ожидание первой телеметрии…'),
          SizedBox(height: 8),
          Text('ESP подключается к Wi-Fi и отправляет данные'),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 72),
            const SizedBox(height: 16),
            Text(
              'Датчик ${_selectedSensor?.name ?? ''} online',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }
}
