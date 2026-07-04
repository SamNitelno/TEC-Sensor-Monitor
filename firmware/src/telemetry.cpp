#include "telemetry.h"

#include "hardware_config.h"
#include "wifi_manager.h"

#include <HTTPClient.h>
#include <WiFi.h>
#include <time.h>

#include <ArduinoJson.h>

namespace {
constexpr uint8_t kMaxPostAttempts = 3;
constexpr uint32_t kNtpWaitMs = 15000;

String iso8601UtcNow() {
  struct tm timeInfo {};
  if (!getLocalTime(&timeInfo, 500)) {
    return "";
  }
  char buffer[32];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &timeInfo);
  return String(buffer) + "Z";
}

bool waitForTimeSync() {
  const uint32_t started = millis();
  struct tm timeInfo {};
  while (millis() - started < kNtpWaitMs) {
    if (getLocalTime(&timeInfo, 200) && timeInfo.tm_year + 1900 >= 2024) {
      return true;
    }
    delay(200);
  }
  Serial.println("NTP sync timeout — sending without timestamp");
  return false;
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
  waitForTimeSync();

  uint32_t lastSend = 0;
  while (true) {
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("Wi-Fi lost — reconnecting");
      connectWifi(config, 20000);
      waitForTimeSync();
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
      if (!sendReading(config, current, power, sensorOk)) {
        Serial.println("Telemetry POST failed — will retry (Wi-Fi stays up)");
      }
    }
    delay(50);
  }
}
