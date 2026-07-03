#include "telemetry.h"

#include "hardware_config.h"

#include <HTTPClient.h>
#include <WiFi.h>
#include <time.h>

#include <ArduinoJson.h>

namespace {
String iso8601UtcNow() {
  struct tm timeInfo {};
  if (!getLocalTime(&timeInfo, 100)) {
    return "";
  }
  char buffer[32];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &timeInfo);
  return String(buffer) + "Z";
}

bool sendReading(const DeviceConfig& config, float currentA, float powerW, bool sensorOk) {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(config.serverUrl)) {
    Serial.println("Invalid server URL");
    return false;
  }
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Token", config.deviceToken);

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

  Serial.printf("Telemetry POST %d body=%s\n", code, body.c_str());
  return code == 202;
}
}  // namespace

void runTelemetryLoop(const DeviceConfig& config, CurrentSensor& sensor) {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  if (!sensor.begin()) {
    Serial.println("Sensor init failed — will retry in loop");
  }

  uint32_t lastSend = 0;
  while (true) {
    if (WiFi.status() != WL_CONNECTED) {
      connectWifi(config);
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
      sendReading(config, current, power, sensorOk);
    }
    delay(50);
  }
}
