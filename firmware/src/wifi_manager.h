#pragma once

#include <Arduino.h>

struct DeviceConfig {
  String ssid;
  String password;
  String serverUrl;
  String deviceToken;
};

bool loadConfigFromNvs(DeviceConfig& config);
bool saveConfigToNvs(const DeviceConfig& config);
bool connectWifi(const DeviceConfig& config, uint32_t timeoutMs = 20000);
