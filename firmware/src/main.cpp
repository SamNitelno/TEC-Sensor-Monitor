#include "ble_provisioning.h"
#include "current_sensor.h"
#include "telemetry.h"
#include "wifi_manager.h"

#include <Arduino.h>

namespace {
CurrentSensor* g_sensor = nullptr;

void onProvisioningCommit(const DeviceConfig& config) {
  Serial.println("Saving config and connecting Wi-Fi...");
  if (!saveConfigToNvs(config)) {
    Serial.println("NVS save failed");
    return;
  }
  stopBleProvisioning();
  if (!connectWifi(config)) {
    Serial.println("Wi-Fi connection failed, restarting BLE");
    startBleProvisioning(onProvisioningCommit);
    return;
  }
  Serial.println("Wi-Fi connected, starting telemetry");
  runTelemetryLoop(config, *g_sensor);
}
}  // namespace

void setup() {
  Serial.begin(115200);
  delay(500);
  g_sensor = createCurrentSensor();

  DeviceConfig config;
  if (loadConfigFromNvs(config) && connectWifi(config)) {
    Serial.println("Loaded config from NVS");
    runTelemetryLoop(config, *g_sensor);
  }

  Serial.println("No valid config — starting BLE provisioning");
  startBleProvisioning(onProvisioningCommit);
}

void loop() {
  pollBleProvisioning();
  delay(20);
}
