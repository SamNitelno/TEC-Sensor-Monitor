#include "telemetry.h"

#include "hardware_config.h"
#include "wifi_manager.h"

#include <HTTPClient.h>
#include <WiFi.h>
#include <time.h>

#include <ArduinoJson.h>

namespace {
constexpr uint8_t kMaxPostAttempts = 3;
// Unix time for 2024-01-01T00:00:00Z — reject SNTP-invalid clocks for telemetry ts.
constexpr time_t kMinValidUnixTime = 1704067200;

bool isTimeSynced() {
  return time(nullptr) >= kMinValidUnixTime;
}

String iso8601UtcNow() {
  if (!isTimeSynced()) {
    return "";
  }
  const time_t now = time(nullptr);
  struct tm timeInfo {};
#if defined(ESP_PLATFORM)
  const struct tm* tmPtr = gmtime(&now);
  if (tmPtr == nullptr) {
    return "";
  }
  timeInfo = *tmPtr;
#else
  if (gmtime_r(&now, &timeInfo) == nullptr) {
    return "";
  }
#endif
  char buffer[32];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeInfo);
  return String(buffer);
}

bool postOnce(const DeviceConfig& config, float currentA, float powerW, bool sensorOk) {
  HTTPClient http;
  http.setConnectTimeout(5000);
  http.setTimeout(10000);
  http.setReuse(false);
  if (!http.begin(config.serverUrl)) {
    Serial.printf("Invalid server URL: %s\n", config.serverUrl.c_str());
    return false;
  }
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Token", config.deviceToken);
  http.addHeader("Connection", "close");

  JsonDocument doc;
  doc["current_a"] = currentA;
  if (sensorOk) {
    doc["power_w"] = powerW;
  }
  const String ts = iso8601UtcNow();
  if (ts.length() > 0) {
    doc["ts"] = ts;
  }

  String body;
  serializeJson(doc, body);
  const int code = http.POST(body);
  http.end();

  Serial.printf("Telemetry POST %d url=%s body=%s\n",
                code, config.serverUrl.c_str(), body.c_str());
  return code == 202;
}

bool sendReading(const DeviceConfig& config, float currentA, float powerW, bool sensorOk) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi not connected");
    return false;
  }

  for (uint8_t attempt = 0; attempt < kMaxPostAttempts; attempt++) {
    if (attempt > 0) {
      delay(400);
    }
    if (postOnce(config, currentA, powerW, sensorOk)) {
      return true;
    }
  }
  return false;
}
}  // namespace

void runTelemetryLoop(const DeviceConfig& config, CurrentSensor& sensor) {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  if (!sensor.begin()) {
    Serial.println("Sensor init failed — will retry in loop");
  }

  Serial.printf("Telemetry target: %s\n", config.serverUrl.c_str());

  uint32_t lastSend = 0;
  while (true) {
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("Wi-Fi lost — reconnecting");
      connectWifi(config, 20000);
      configTime(0, 0, "pool.ntp.org", "time.nist.gov");
      lastSend = 0;
      continue;
    }

    const uint32_t now = millis();
    if (lastSend == 0 || now - lastSend >= kTelemetryIntervalMs) {
      lastSend = now;
      const float current = sensor.readCurrentA();
      const float power = sensor.readPowerW();
      const bool sensorOk = sensor.ok();
      Serial.printf("[CAL] I=%.4f A P=%.1f W ok=%d scale=%.4f\n",
                    current, power, sensorOk ? 1 : 0, CURRENT_SCALE);
      if (!sendReading(config, current, power, sensorOk)) {
        Serial.println("Telemetry POST failed — will retry (Wi-Fi stays up)");
      }
    }
    delay(50);
  }
}
