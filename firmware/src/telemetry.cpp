#include "telemetry.h"

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

bool sendReading(const DeviceConfig& config, float currentA) {
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
      const float current = sensor.readCurrentAmps();
      sendReading(config, current);
    }
    delay(50);
  }
}
