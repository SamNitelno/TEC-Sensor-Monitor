#include "wifi_manager.h"

#include <Preferences.h>
#include <WiFi.h>

namespace {
constexpr char kNvsNamespace[] = "tec_cfg";
constexpr char kKeySsid[] = "ssid";
constexpr char kKeyPassword[] = "password";
constexpr char kKeyServerUrl[] = "server_url";
constexpr char kKeyDeviceToken[] = "device_token";
constexpr char kKeyConfigured[] = "configured";
}  // namespace

bool loadConfigFromNvs(DeviceConfig& config) {
  Preferences prefs;
  if (!prefs.begin(kNvsNamespace, true)) {
    return false;
  }
  const bool configured = prefs.getBool(kKeyConfigured, false);
  if (!configured) {
    prefs.end();
    return false;
  }
  config.ssid = prefs.getString(kKeySsid, "");
  config.password = prefs.getString(kKeyPassword, "");
  config.serverUrl = prefs.getString(kKeyServerUrl, "");
  config.deviceToken = prefs.getString(kKeyDeviceToken, "");
  prefs.end();
  return config.ssid.length() > 0 && config.serverUrl.length() > 0 &&
         config.deviceToken.length() > 0;
}

bool saveConfigToNvs(const DeviceConfig& config) {
  Preferences prefs;
  if (!prefs.begin(kNvsNamespace, false)) {
    return false;
  }
  prefs.putString(kKeySsid, config.ssid);
  prefs.putString(kKeyPassword, config.password);
  prefs.putString(kKeyServerUrl, config.serverUrl);
  prefs.putString(kKeyDeviceToken, config.deviceToken);
  prefs.putBool(kKeyConfigured, true);
  prefs.end();
  return true;
}

bool connectWifi(const DeviceConfig& config, uint32_t timeoutMs) {
  if (WiFi.status() == WL_CONNECTED && WiFi.SSID() == config.ssid) {
    return true;
  }
  WiFi.mode(WIFI_STA);
  WiFi.begin(config.ssid.c_str(), config.password.c_str());
  const uint32_t started = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - started < timeoutMs) {
    delay(250);
  }
  return WiFi.status() == WL_CONNECTED;
}
