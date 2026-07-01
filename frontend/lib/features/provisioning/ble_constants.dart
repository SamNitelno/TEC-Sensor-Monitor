/// BLE GATT UUIDs — must match firmware/src/ble_uuids.h
class BleConstants {
  BleConstants._();

  static const provisioningServiceUuid = 'aec0c101-5a56-4ef2-882b-d1e0e0b4d8ba';
  static const ssidCharacteristicUuid = 'aec0c102-5a56-4ef2-882b-d1e0e0b4d8ba';
  static const passwordCharacteristicUuid = 'aec0c103-5a56-4ef2-882b-d1e0e0b4d8ba';
  static const serverUrlCharacteristicUuid = 'aec0c104-5a56-4ef2-882b-d1e0e0b4d8ba';
  static const deviceTokenCharacteristicUuid = 'aec0c105-5a56-4ef2-882b-d1e0e0b4d8ba';
  static const commitCharacteristicUuid = 'aec0c106-5a56-4ef2-882b-d1e0e0b4d8ba';

  static const deviceNamePrefix = 'TEC-ESP';
}
