#pragma once

// JSY-MK-194G UART / Modbus — override via platformio build_flags if needed.
#ifndef JSY_UART_RX_PIN
#define JSY_UART_RX_PIN 33  // ESP RX <- module TX (Green)
#endif
#ifndef JSY_UART_TX_PIN
#define JSY_UART_TX_PIN 32  // ESP TX -> module RX (Green)
#endif
#ifndef JSY_MODBUS_BAUD
#define JSY_MODBUS_BAUD 4800
#endif
#ifndef JSY_MODBUS_ADDRESS
#define JSY_MODBUS_ADDRESS 1
#endif

// Optional correction when CT range differs from module defaults (e.g. 150A CT).
#ifndef CURRENT_SCALE
#define CURRENT_SCALE 1.0f
#endif

// 1 = on-board CT (CT1), 2 = external clamp CT2 (SCTK681A on test stand).
#ifndef JSY_MEASURE_CHANNEL
#define JSY_MEASURE_CHANNEL 2
#endif

// Raw Modbus fallback: base register for measurement block (JSY-MK-194 manual).
#ifndef JSY_REG_BASE
#define JSY_REG_BASE 0x0048
#endif
// Word offsets from JSY_REG_BASE within the 0x0048 block (channel 1).
#ifndef JSY_OFF_CURRENT1
#define JSY_OFF_CURRENT1 1  // 0x0049 CH1 current, unit 0.01 A (raw Modbus)
#endif
#ifndef JSY_OFF_POWER1
#define JSY_OFF_POWER1 2  // 0x004A CH1 active power, unit 1 W
#endif
#ifndef JSY_OFF_CURRENT2
#define JSY_OFF_CURRENT2 9  // 0x0051 CH2 current
#endif
#ifndef JSY_OFF_POWER2
#define JSY_OFF_POWER2 10  // 0x0052 CH2 active power
#endif
