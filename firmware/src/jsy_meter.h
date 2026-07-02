#pragma once

#include "current_sensor.h"

#if defined(USE_JSY_SENSOR) && USE_JSY_SENSOR
CurrentSensor* createCurrentSensor();
#endif
