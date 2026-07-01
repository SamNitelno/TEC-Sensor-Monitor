import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_constants.dart';

class BleProvisioningException implements Exception {
  BleProvisioningException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DiscoveredBleDevice {
  const DiscoveredBleDevice({
    required this.device,
    required this.name,
    required this.rssi,
  });

  final BluetoothDevice device;
  final String name;
  final int rssi;
}

class BleProvisioningService {
  Stream<List<DiscoveredBleDevice>> scanForEspDevices({
    Duration timeout = const Duration(seconds: 15),
  }) async* {
    final seen = <String, DiscoveredBleDevice>{};

    await FlutterBluePlus.startScan(
      withServices: [Guid(BleConstants.provisioningServiceUuid)],
      timeout: timeout,
    );

    await for (final results in FlutterBluePlus.scanResults) {
      for (final result in results) {
        final id = result.device.remoteId.str;
        final name = result.device.platformName.isNotEmpty
            ? result.device.platformName
            : result.advertisementData.advName;
        seen[id] = DiscoveredBleDevice(
          device: result.device,
          name: name.isNotEmpty ? name : id,
          rssi: result.rssi,
        );
      }
      yield seen.values.toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
    }
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> connect(BluetoothDevice device) async {
    await device.connect(
      timeout: const Duration(seconds: 15),
      license: License.nonprofit,
    );
  }

  Future<void> disconnect(BluetoothDevice device) async {
    await device.disconnect();
  }

  Future<void> provision({
    required BluetoothDevice device,
    required String ssid,
    required String password,
    required String serverUrl,
    required String deviceToken,
  }) async {
    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == Guid(BleConstants.provisioningServiceUuid),
      orElse: () => throw BleProvisioningException('Сервис привязки не найден'),
    );

    Future<void> write(String uuid, String value) async {
      final characteristic = service.characteristics.firstWhere(
        (c) => c.uuid == Guid(uuid),
        orElse: () => throw BleProvisioningException('Характеристика $uuid не найдена'),
      );
      await characteristic.write(utf8.encode(value), withoutResponse: false);
    }

    await write(BleConstants.ssidCharacteristicUuid, ssid);
    await write(BleConstants.passwordCharacteristicUuid, password);
    await write(BleConstants.serverUrlCharacteristicUuid, serverUrl);
    await write(BleConstants.deviceTokenCharacteristicUuid, deviceToken);
    await write(BleConstants.commitCharacteristicUuid, '1');
  }
}
