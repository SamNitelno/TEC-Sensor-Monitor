import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/features/provisioning/ble_provisioning_service.dart';

final bleProvisioningServiceProvider = Provider<BleProvisioningService>(
  (ref) => BleProvisioningService(),
);
