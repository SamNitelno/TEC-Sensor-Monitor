#include "ble_provisioning.h"
#include "current_sensor.h"
#include "telemetry.h"
#include "wifi_manager.h"

#include <Arduino.h>

#if defined(HARDCODED_CONFIG) && HARDCODED_CONFIG
#include "secrets.h"
#endif

namespace {
CurrentSensor* g_sensor = nullptr;

#if defined(HARDCODED_CONFIG) && HARDCODED_CONFIG
DeviceConfig hardcodedConfig() {
  DeviceConfig config;
  config.ssid = HC_WIFI_SSID;
  config.password = HC_WIFI_PASSWORD;
  config.serverUrl = HC_SERVER_URL;
  config.deviceToken = HC_DEVICE_TOKEN;
  return config;
}

void startHardcodedTelemetry() {
  Serial.println("HARDCODED_CONFIG: skipping NVS and BLE");
  const DeviceConfig config = hardcodedConfig();
  if (!connectWifi(config)) {
    Serial.println("HARDCODED_CONFIG: Wi-Fi connection failed — check secrets.h");
    return;
  }
  Serial.println("HARDCODED_CONFIG: Wi-Fi OK, starting telemetry");
  runTelemetryLoop(config, *g_sensor);
}
#endif

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

#if defined(WIPE_NVS) && WIPE_NVS
  Serial.println("WIPE_NVS: one-time NVS erase");
  wipeAllNvs();
#endif

  g_sensor = createCurrentSensor();
  if (!g_sensor->begin()) {
    Serial.println("Warning: sensor not ready at boot");
  }

#if defined(HARDCODED_CONFIG) && HARDCODED_CONFIG
  startHardcodedTelemetry();
  return;
#endif

  DeviceConfig config;
  if (loadConfigFromNvs(config) && connectWifi(config)) {
    Serial.println("Loaded config from NVS");
    runTelemetryLoop(config, *g_sensor);
  }

  Serial.println("No valid config — starting BLE provisioning");
  startBleProvisioning(onProvisioningCommit);
}

void loop() {
#if defined(HARDCODED_CONFIG) && HARDCODED_CONFIG
  return;
#endif
  pollBleProvisioning();
  delay(20);
}
