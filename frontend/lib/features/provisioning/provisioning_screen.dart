import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';
import 'package:tek_sensor_monitor/core/api_url_provider.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_constants.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_platform.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_provisioning_service.dart';
import 'package:tek_sensor_monitor/features/provisioning/provisioning_providers.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
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
  final _tokenController = TextEditingController();

  Sensor? _selectedSensor;
  bool _tokenFromServer = false;
  bool _rotatingToken = false;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _serverUrlInitialized = false;

  @override
  void initState() {
    super.initState();
    if (isBleProvisioningSupported) {
      // The stream emits the current state first, so this also kicks off the
      // initial scan once the adapter is known to be on.
      _adapterSubscription = FlutterBluePlus.adapterState.listen(
        _onAdapterState,
        onError: (Object e) {
          if (mounted) setState(() => _error = e.toString());
        },
      );
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
    _adapterSubscription?.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    _tokenController.dispose();
    _selectedDevice?.disconnect().catchError((_) {});
    ref.read(bleProvisioningServiceProvider).stopScan();
    super.dispose();
  }

  BleProvisioningService get _ble => ref.read(bleProvisioningServiceProvider);

  /// Adapter can be switched on from the app only on Android.
  bool get _canTurnOnAdapter =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// App settings page exists on mobile only.
  bool get _canOpenAppSettings =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _adapterReady => _adapterState == BluetoothAdapterState.on;

  bool get _adapterPending =>
      _adapterState == BluetoothAdapterState.unknown ||
      _adapterState == BluetoothAdapterState.turningOn;

  void _onAdapterState(BluetoothAdapterState state) {
    if (!mounted) return;
    final wasReady = _adapterReady;
    setState(() {
      _adapterState = state;
      if (state == BluetoothAdapterState.on) {
        _error = null;
      }
    });
    if (state == BluetoothAdapterState.on &&
        !wasReady &&
        _step == ProvisioningStep.scan &&
        !_scanning) {
      _startScan();
    }
  }

  Future<void> _turnOnAdapter() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      if (mounted) setState(() => _error = _describeBleError(e, context.l10n));
    }
  }

  /// BLE errors arrive as raw platform text — map the two common ones.
  String _describeBleError(Object error, AppLocalizations l10n) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('permission')) {
      return l10n.blePermissionRequired;
    }
    if (lower.contains('turned on') || lower.contains('adapter is off')) {
      return l10n.bleAdapterOff;
    }
    return text;
  }

  Future<void> _startScan() async {
    if (!_adapterReady) {
      setState(() => _error = context.l10n.bleAdapterOff);
      return;
    }
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
      if (mounted) setState(() => _error = _describeBleError(e, context.l10n));
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
      if (mounted) setState(() => _error = l10n.connectFailed(e.toString()));
    }
  }

  Future<void> _selectSensor(Sensor? sensor) async {
    final l10n = context.l10n;
    if (sensor == null) {
      setState(() {
        _selectedSensor = null;
        _tokenFromServer = false;
        _tokenController.clear();
      });
      return;
    }
    setState(() {
      _error = null;
      _selectedSensor = sensor;
      _tokenFromServer = false;
      _tokenController.clear();
    });
    try {
      final creds =
          await ref.read(apiClientProvider).fetchProvisioningToken(sensor.id);
      if (!mounted) return;
      setState(() {
        _serverUrlController.text = creds.ingestUrl;
        // Tokens are stored hashed: plaintext comes back only right after
        // creation. Otherwise the admin pastes it or issues a new one.
        if (creds.hasToken) {
          _tokenController.text = creds.apiToken!;
          _tokenFromServer = true;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = l10n.tokenFetchFailed(e.toString()));
      }
    }
  }

  Future<void> _rotateToken() async {
    final sensor = _selectedSensor;
    if (sensor == null) {
      setState(() => _error = context.l10n.selectDeviceAndSensor);
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rotateTokenTitle),
        content: Text(l10n.rotateTokenWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.rotateTokenConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _rotatingToken = true;
      _error = null;
    });
    try {
      final creds =
          await ref.read(apiClientProvider).rotateSensorToken(sensor.id);
      if (!mounted) return;
      setState(() {
        _serverUrlController.text = creds.ingestUrl;
        _tokenController.text = creds.apiToken ?? '';
        _tokenFromServer = creds.hasToken;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tokenRotated)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = l10n.tokenRotateFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _rotatingToken = false);
    }
  }

  Future<void> _commitProvisioning() async {
    final l10n = context.l10n;
    final device = _selectedDevice;
    final sensor = _selectedSensor;
    final token = _tokenController.text.trim();
    if (device == null || sensor == null) {
      setState(() => _error = l10n.selectDeviceAndSensor);
      return;
    }
    if (token.isEmpty) {
      setState(() => _error = l10n.tokenRequired);
      return;
    }
    if (_ssidController.text.trim().isEmpty) {
      setState(() => _error = l10n.ssidRequired);
      return;
    }
    if (_serverUrlController.text.trim().isEmpty) {
      setState(() => _error = l10n.ingestUrlRequired);
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
      if (mounted) {
        setState(() {
          _error = e is BleProvisioningException ? e.message : e.toString();
          _step = ProvisioningStep.configure;
        });
      }
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
        if (_scanning) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.scanInstructions,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (!_adapterReady && !_adapterPending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildAdapterCard(),
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

  /// Bluetooth is off / not permitted — say so and offer the way out.
  Widget _buildAdapterCard() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isUnauthorized = _adapterState == BluetoothAdapterState.unauthorized;
    final isUnavailable = _adapterState == BluetoothAdapterState.unavailable;

    final String message;
    if (isUnauthorized) {
      message = l10n.blePermissionRequired;
    } else if (isUnavailable) {
      message = l10n.bleUnavailable;
    } else {
      message = l10n.bleAdapterOff;
    }

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth_disabled,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (!isUnavailable) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: isUnauthorized
                    ? (_canOpenAppSettings
                        ? FilledButton.icon(
                            onPressed: openAppSettings,
                            icon: const Icon(Icons.settings),
                            label: Text(l10n.openAppSettings),
                          )
                        : Text(
                            l10n.bleTurnOnManually,
                            style: theme.textTheme.bodySmall,
                          ))
                    : (_canTurnOnAdapter
                        ? FilledButton.icon(
                            onPressed: _turnOnAdapter,
                            icon: const Icon(Icons.bluetooth),
                            label: Text(l10n.bleTurnOn),
                          )
                        : Text(
                            l10n.bleTurnOnManually,
                            style: theme.textTheme.bodySmall,
                          )),
              ),
            ],
          ],
        ),
      ),
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
            // Value is the sensor id: the list can be refetched while this
            // screen is open, and fresh Sensor objects would break equality.
            DropdownButtonFormField<int?>(
              value: sensors.any((s) => s.id == _selectedSensor?.id)
                  ? _selectedSensor?.id
                  : null,
              decoration: InputDecoration(
                labelText: l10n.systemSensorLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.selectPlaceholder)),
                ...sensors.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.name} (${s.deviceId})'),
                  ),
                ),
              ],
              onChanged: (id) => _selectSensor(
                id == null ? null : sensors.firstWhere((s) => s.id == id),
              ),
            ),
            if (sensors.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.noSensorsForProvisioning,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              onChanged: (_) => setState(() => _tokenFromServer = false),
              decoration: InputDecoration(
                labelText: l10n.deviceTokenLabel,
                border: const OutlineInputBorder(),
                helperText: l10n.deviceTokenHelper,
                helperMaxLines: 3,
              ),
            ),
            if (_tokenFromServer && _tokenController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.tokenLoaded(_tokenController.text.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed:
                    _rotatingToken || _selectedSensor == null ? null : _rotateToken,
                icon: _rotatingToken
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.autorenew),
                label: Text(l10n.issueNewToken),
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
