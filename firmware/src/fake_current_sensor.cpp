#include "current_sensor.h"

#include <cmath>
#include <ctime>

class FakeCurrentSensor : public CurrentSensor {
 public:
  float readCurrentAmps() override {
    const unsigned long ms = millis();
    const float t = ms / 1000.0f;
    const float base = 3.5f + 1.2f * sinf(t / 17.0f);
    const float noise = (static_cast<int>(ms % 100) - 50) / 500.0f;
    return base + noise > 0.0f ? base + noise : 0.0f;
  }
};

CurrentSensor* createCurrentSensor() { return new FakeCurrentSensor(); }
