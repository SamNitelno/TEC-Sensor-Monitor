import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';
import 'package:tek_sensor_monitor/core/api_url_provider.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_constants.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_platform.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_provisioning_service.dart';
import 'package:tek_sensor_monitor/features/provisioning/provisioning_providers.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';
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
  bool _serverUrlInitialized = false;

  @override
  void initState() {
    super.initState();
    if (isBleProvisioningSupported) {
      _startScan();
    }
  }

  void _initServerUrlFromProvider() {
    if (_serverUrlInitialized) return;
    final baseUrl = ref.read(apiBaseUrlProvider).valueOrNull ?? defaultApiBaseUrl;
    _serverUrlController.text =
        '${baseUrl.replaceAll(RegExp(r'/$'), '')}/api/v1/ingest';
    _serverUrlInitialized = true;
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
    final l10n = context.l10n;
    setState(() {
      _error = null;
      _selectedDevice = item.device;
    });
    try {
      await _ble.connect(item.device);
      if (mounted) setState(() => _step = ProvisioningStep.configure);
    } catch (e) {
      setState(() => _error = l10n.connectFailed(e.toString()));
    }
  }

  Future<void> _loadTokenForSensor(Sensor? sensor) async {
    final l10n = context.l10n;
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
      setState(() => _error = l10n.tokenFetchFailed(e.toString()));
    }
  }

  Future<void> _commitProvisioning() async {
    final l10n = context.l10n;
    final device = _selectedDevice;
    final token = _deviceToken;
    final sensor = _selectedSensor;
    if (device == null || token == null || sensor == null) {
      setState(() => _error = l10n.selectDeviceAndSensor);
      return;
    }
    if (_ssidController.text.trim().isEmpty) {
      setState(() => _error = l10n.ssidRequired);
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
        l10n: l10n,
      );
      await device.disconnect();
      _startOnlinePolling(sensor.id);
    } catch (e) {
      setState(() {
        _error = e is BleProvisioningException
            ? e.message
            : e.toString();
        _step = ProvisioningStep.configure;
      });
    }
  }

  void _startOnlinePolling(int sensorId) {
    final l10n = context.l10n;
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
            _error = l10n.onlineTimeout;
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
    final l10n = context.l10n;
    ref.watch(apiBaseUrlProvider);
    _initServerUrlFromProvider();
    if (!isBleProvisioningSupported) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.provisioningTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.provisioningUnavailableWeb,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.provisioningTitle),
        actions: [
          if (_step == ProvisioningStep.scan)
            IconButton(
              onPressed: _scanning ? null : _startScan,
              icon: const Icon(Icons.refresh),
              tooltip: l10n.rescanTooltip,
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
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_scanning)
          const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.scanInstructions,
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
                  child: Text(_scanning ? l10n.scanning : l10n.noDevicesFound),
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
    final l10n = context.l10n;
    final sensorsAsync = ref.watch(sensorsProvider);
    final deviceName = _selectedDevice?.platformName.isNotEmpty == true
        ? _selectedDevice!.platformName
        : _selectedDevice?.remoteId.str ?? '';

    return sensorsAsync.when(
      loading: () => const TekPageLoading(),
      error: (e, _) =>
          Center(child: Text(l10n.provisioningSensorsLoadError(e.toString()))),
      data: (sensors) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.connectedTo(deviceName),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ssidController,
              decoration: InputDecoration(
                labelText: l10n.wifiSsidLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.wifiPasswordLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                labelText: l10n.ingestUrlLabel,
                border: const OutlineInputBorder(),
                helperText: l10n.ingestUrlHelper,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Sensor?>(
              value: _selectedSensor,
              decoration: InputDecoration(
                labelText: l10n.systemSensorLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.selectPlaceholder)),
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
                  l10n.tokenLoaded(_deviceToken!.length),
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
              label: Text(l10n.commitButton),
            ),
            TextButton(
              onPressed: () => setState(() => _step = ProvisioningStep.scan),
              child: Text(l10n.selectOtherDevice),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingStep() {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TekLoadingIndicator(size: 48, message: l10n.waitingTelemetry),
          const SizedBox(height: 8),
          Text(
            l10n.waitingDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 72),
            const SizedBox(height: 16),
            Text(
              l10n.successOnline(_selectedSensor?.name ?? ''),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }
}
