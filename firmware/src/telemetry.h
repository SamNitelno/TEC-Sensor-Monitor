#pragma once

#include "current_sensor.h"
#include "wifi_manager.h"

constexpr uint32_t kTelemetryIntervalMs = 5000;

void runTelemetryLoop(const DeviceConfig& config, CurrentSensor& sensor);
