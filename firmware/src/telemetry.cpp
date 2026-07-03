#include "telemetry.h"

#include "hardware_config.h"
#include "wifi_manager.h"

#include <HTTPClient.h>
#include <WiFi.h>
#include <time.h>

#include <ArduinoJson.h>

namespace {
constexpr uint8_t kMaxPostAttempts = 3;
constexpr uint8_t kFailuresBeforeWifiReset = 5;

String iso8601UtcNow() {
  struct tm timeInfo {};
  if (!getLocalTime(&timeInfo, 500)) {
    return "";
  }
  char buffer[32];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &timeInfo);
  return String(buffer) + "Z";
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

void resetWifiLink(const DeviceConfig& config) {
  Serial.printf("Resetting Wi-Fi (IP was %s)\n", WiFi.localIP().toString().c_str());
  WiFi.disconnect(false);
  delay(250);
  connectWifi(config, 20000);
}
}  // namespace

void runTelemetryLoop(const DeviceConfig& config, CurrentSensor& sensor) {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  if (!sensor.begin()) {
    Serial.println("Sensor init failed — will retry in loop");
  }

  uint32_t lastSend = 0;
  uint8_t sendFailures = 0;
  while (true) {
    if (WiFi.status() != WL_CONNECTED) {
      connectWifi(config, 20000);
      delay(1000);
      continue;
    }

    const uint32_t now = millis();
    if (now - lastSend >= kTelemetryIntervalMs) {
      lastSend = now;
      const float current = sensor.readCurrentA();
      const float power = sensor.readPowerW();
      const bool sensorOk = sensor.ok();
      Serial.printf("[CAL] I=%.4f A P=%.1f W ok=%d scale=%.4f\n",
                    current, power, sensorOk ? 1 : 0, CURRENT_SCALE);
      if (sendReading(config, current, power, sensorOk)) {
        sendFailures = 0;
      } else {
        sendFailures++;
        if (sendFailures >= kFailuresBeforeWifiReset) {
          resetWifiLink(config);
          sendFailures = 0;
        }
      }
    }
    delay(50);
  }
}
