#include "current_sensor.h"

#include <Arduino.h>
#include <cmath>

#include "hardware_config.h"

class FakeCurrentSensor : public CurrentSensor {
 public:
  bool begin() override {
    _ok = true;
    return true;
  }

  float readCurrentA() override {
    const unsigned long ms = millis();
    const float t = ms / 1000.0f;
    const float base = 3.5f + 1.2f * sinf(t / 17.0f);
    const float noise = (static_cast<int>(ms % 100) - 50) / 500.0f;
    const float value = base + noise;
    _lastCurrent = value > 0.0f ? value * CURRENT_SCALE : 0.0f;
    _lastPower = _lastCurrent * 230.0f;
    return _lastCurrent;
  }

  float readPowerW() override { return _lastPower; }

  bool ok() const override { return _ok; }

 private:
  bool _ok = false;
  float _lastCurrent = 0.0f;
  float _lastPower = 0.0f;
};

#if defined(USE_FAKE_SENSOR) && USE_FAKE_SENSOR
CurrentSensor* createCurrentSensor() { return new FakeCurrentSensor(); }
#endif
