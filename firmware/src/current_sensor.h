#pragma once

class CurrentSensor {
 public:
  virtual ~CurrentSensor() = default;
  virtual bool begin() = 0;
  virtual float readCurrentA() = 0;
  virtual float readPowerW() = 0;
  virtual bool ok() const = 0;
};

CurrentSensor* createCurrentSensor();
