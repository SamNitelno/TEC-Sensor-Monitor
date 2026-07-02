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

// Raw Modbus fallback: base register for measurement block (JSY-MK-194 manual).
#ifndef JSY_REG_BASE
#define JSY_REG_BASE 0x0048
#endif
// Word offsets from JSY_REG_BASE within the 0x0048 block (channel 1).
#ifndef JSY_OFF_CURRENT1
#define JSY_OFF_CURRENT1 2  // 0x004A, unit 0.01 A
#endif
#ifndef JSY_OFF_POWER1
#define JSY_OFF_POWER1 6  // 0x004E, unit 1 W
#endif
