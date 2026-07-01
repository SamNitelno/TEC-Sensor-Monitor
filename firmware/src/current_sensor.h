#pragma once

class CurrentSensor {
 public:
  virtual ~CurrentSensor() = default;
  virtual float readCurrentAmps() = 0;
};

CurrentSensor* createCurrentSensor();
