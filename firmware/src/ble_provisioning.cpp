#include "ble_provisioning.h"

#include "ble_uuids.h"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

namespace {
DeviceConfig g_pendingConfig;
ProvisioningCommitHandler g_onCommit;
BLEServer* g_server = nullptr;
bool g_commitRequested = false;

class CommitCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    const std::string value = characteristic->getValue();
    if (value.empty()) {
      return;
    }
    g_commitRequested = true;
    Serial.println("BLE commit received");
  }
};

class StringCallbacks : public BLECharacteristicCallbacks {
 public:
  explicit StringCallbacks(String DeviceConfig::*field)
      : field_(field) {}

  void onWrite(BLECharacteristic* characteristic) override {
    const std::string value = characteristic->getValue();
    g_pendingConfig.*field_ = String(value.c_str());
    Serial.printf("BLE write %s\n", value.c_str());
  }

 private:
  String DeviceConfig::*;
};

void applyCommit() {
  if (!g_onCommit) {
    return;
  }
  if (g_pendingConfig.ssid.isEmpty() || g_pendingConfig.serverUrl.isEmpty() ||
      g_pendingConfig.deviceToken.isEmpty()) {
    Serial.println("BLE commit rejected: missing fields");
    return;
  }
  g_onCommit(g_pendingConfig);
}
}  // namespace

void startBleProvisioning(ProvisioningCommitHandler onCommit) {
  g_onCommit = std::move(onCommit);
  g_pendingConfig = DeviceConfig{};
  g_commitRequested = false;

  BLEDevice::init(TEC_BLE_DEVICE_NAME);
  g_server = BLEDevice::createServer();

  BLEService* service =
      g_server->createService(BLEUUID(TEC_BLE_SERVICE_UUID));

  service->createCharacteristic(TEC_BLE_CHAR_SSID_UUID, BLECharacteristic::PROPERTY_WRITE)
      ->setCallbacks(new StringCallbacks(&DeviceConfig::ssid));
  service->createCharacteristic(TEC_BLE_CHAR_PASSWORD_UUID, BLECharacteristic::PROPERTY_WRITE)
      ->setCallbacks(new StringCallbacks(&DeviceConfig::password));
  service->createCharacteristic(TEC_BLE_CHAR_SERVER_URL_UUID, BLECharacteristic::PROPERTY_WRITE)
      ->setCallbacks(new StringCallbacks(&DeviceConfig::serverUrl));
  service->createCharacteristic(TEC_BLE_CHAR_DEVICE_TOKEN_UUID, BLECharacteristic::PROPERTY_WRITE)
      ->setCallbacks(new StringCallbacks(&DeviceConfig::deviceToken));
  service->createCharacteristic(TEC_BLE_CHAR_COMMIT_UUID,
                              BLECharacteristic::PROPERTY_WRITE)
      ->setCallbacks(new CommitCallbacks());

  service->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(TEC_BLE_SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->start();

  Serial.println("BLE provisioning started");
}

void stopBleProvisioning() {
  BLEDevice::deinit(true);
  g_server = nullptr;
}

void pollBleProvisioning() {
  if (g_commitRequested) {
    g_commitRequested = false;
    applyCommit();
  }
}
