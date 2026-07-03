#include "jsy_meter.h"

#include "hardware_config.h"

#include <HardwareSerial.h>

#if defined(USE_MYCILA_JSY) && USE_MYCILA_JSY
#include <MycilaJSY.h>

namespace {
Mycila::JSY g_jsy;
Mycila::JSY::Data g_jsyData;
volatile bool g_hasData = false;

const Mycila::JSY::Metrics& measureChannel(const Mycila::JSY::Data& data) {
#if JSY_MEASURE_CHANNEL == 2
  return data.channel2();
#else
  return data.channel1();
#endif
}

void logJsyChannels(const Mycila::JSY::Data& data) {
  const auto& m = measureChannel(data);
  Serial.printf(
      "JSY ch%d: I=%.3fA P=%.1fW V=%.1fV (ch1 I=%.3f P=%.1f | ch2 I=%.3f P=%.1f)\n",
      JSY_MEASURE_CHANNEL,
      m.current * CURRENT_SCALE,
      m.activePower,
      m.voltage,
      data.channel1().current * CURRENT_SCALE,
      data.channel1().activePower,
      data.channel2().current * CURRENT_SCALE,
      data.channel2().activePower);
}

Mycila::JSY::BaudRate baudFromConfig() {
  switch (JSY_MODBUS_BAUD) {
    case 4800:
      return Mycila::JSY::BaudRate::BAUD_4800;
    case 9600:
      return Mycila::JSY::BaudRate::BAUD_9600;
    case 19200:
      return Mycila::JSY::BaudRate::BAUD_19200;
    case 38400:
      return Mycila::JSY::BaudRate::BAUD_38400;
    default:
      return Mycila::JSY::BaudRate::UNKNOWN;
  }
}
}  // namespace

class JsyCurrentSensor : public CurrentSensor {
 public:
  bool begin() override {
    g_jsy.begin(
        Serial2,
        JSY_UART_RX_PIN,
        JSY_UART_TX_PIN,
        baudFromConfig(),
        static_cast<uint8_t>(JSY_MODBUS_ADDRESS),
        MYCILA_JSY_MK_194);
    g_jsy.setCallback([](Mycila::JSY::EventType eventType, const Mycila::JSY::Data& data) {
      if (eventType == Mycila::JSY::EventType::EVT_READ) {
        g_jsyData = data;
        g_hasData = true;
      }
    });
    const bool readOk = g_jsy.read();
    _ok = readOk && g_hasData;
    if (_ok) {
      logJsyChannels(g_jsyData);
    } else {
      Serial.println("JSY begin: Modbus read failed");
    }
    return _ok;
  }

  float readCurrentA() override {
    if (!g_jsy.read() && !g_hasData) {
      _ok = false;
      Serial.println("JSY read failed");
      return _lastCurrent;
    }
    const auto& m = measureChannel(g_jsyData);
    _lastCurrent = m.current * CURRENT_SCALE;
    _lastPower = m.activePower;
    _ok = true;
    logJsyChannels(g_jsyData);
    return _lastCurrent;
  }

  float readPowerW() override { return _lastPower; }

  bool ok() const override { return _ok; }

 private:
  bool _ok = false;
  float _lastCurrent = 0.0f;
  float _lastPower = 0.0f;
};

#else  // raw Modbus fallback

namespace {
uint16_t modbusCrc(const uint8_t* data, size_t len) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < len; ++i) {
    crc ^= data[i];
    for (int bit = 0; bit < 8; ++bit) {
      if (crc & 0x0001) {
        crc = (crc >> 1) ^ 0xA001;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc;
}

bool modbusReadHolding(uint8_t address, uint16_t startReg, uint16_t count, uint16_t* out) {
  uint8_t request[8] = {
      address,
      0x03,
      static_cast<uint8_t>((startReg >> 8) & 0xFF),
      static_cast<uint8_t>(startReg & 0xFF),
      static_cast<uint8_t>((count >> 8) & 0xFF),
      static_cast<uint8_t>(count & 0xFF),
  };
  const uint16_t crc = modbusCrc(request, 6);
  request[6] = static_cast<uint8_t>(crc & 0xFF);
  request[7] = static_cast<uint8_t>((crc >> 8) & 0xFF);

  while (Serial2.available()) {
    Serial2.read();
  }
  Serial2.write(request, sizeof(request));
  Serial2.flush();

  const size_t expected = 5 + count * 2;
  uint8_t response[64] = {};
  size_t received = 0;
  const uint32_t deadline = millis() + 500;
  while (received < expected && millis() < deadline) {
    while (Serial2.available() && received < sizeof(response)) {
      response[received++] = Serial2.read();
    }
  }
  if (received < 5) {
    return false;
  }
  const uint16_t respCrc = static_cast<uint16_t>(response[received - 2]) |
                         (static_cast<uint16_t>(response[received - 1]) << 8);
  if (modbusCrc(response, received - 2) != respCrc) {
    return false;
  }
  if (response[0] != address || response[1] != 0x03) {
    return false;
  }
  const uint8_t byteCount = response[2];
  if (byteCount != count * 2) {
    return false;
  }
  for (uint16_t i = 0; i < count; ++i) {
    out[i] = static_cast<uint16_t>(response[3 + i * 2] << 8) | response[4 + i * 2];
  }
  return true;
}
}  // namespace

class JsyCurrentSensor : public CurrentSensor {
 public:
  bool begin() override {
    Serial2.begin(JSY_MODBUS_BAUD, SERIAL_8N1, JSY_UART_RX_PIN, JSY_UART_TX_PIN);
    delay(100);
    _ok = refresh();
    return _ok;
  }

  float readCurrentA() override {
    refresh();
    return _lastCurrent;
  }

  float readPowerW() override {
    refresh();
    return _lastPower;
  }

  bool ok() const override { return _ok; }

 private:
  bool refresh() {
    uint16_t regs[16] = {};
    if (!modbusReadHolding(static_cast<uint8_t>(JSY_MODBUS_ADDRESS), JSY_REG_BASE, 16, regs)) {
      _ok = false;
      Serial.println("JSY raw Modbus read failed");
      return false;
    }
#if JSY_MEASURE_CHANNEL == 2
    const uint16_t curReg = regs[JSY_OFF_CURRENT2];
    const uint16_t pwrReg = regs[JSY_OFF_POWER2];
#else
    const uint16_t curReg = regs[JSY_OFF_CURRENT1];
    const uint16_t pwrReg = regs[JSY_OFF_POWER1];
#endif
    const float current = curReg * 0.01f * CURRENT_SCALE;
    const float power = static_cast<float>(pwrReg);
    _lastCurrent = current >= 0.0f ? current : 0.0f;
    _lastPower = power;
    _ok = true;
    Serial.printf("JSY raw ch%d: I=%.3fA P=%.1fW\n", JSY_MEASURE_CHANNEL, _lastCurrent, _lastPower);
    return true;
  }

  bool _ok = false;
  float _lastCurrent = 0.0f;
  float _lastPower = 0.0f;
};

#endif

#if defined(USE_JSY_SENSOR) && USE_JSY_SENSOR
CurrentSensor* createCurrentSensor() { return new JsyCurrentSensor(); }
#endif
