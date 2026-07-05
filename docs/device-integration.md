# Интеграция устройств (HTTP-телеметрия)

Контракт приёма данных от датчиков (ESP32 + JSY-MK-194G и совместимые устройства). Используется прошивкой, эмулятором и MQTT-веткой — **не менять без согласования**.

## Эндпоинт

| Параметр | Значение |
|----------|----------|
| **URL** | `POST /api/v1/ingest` |
| **Полный URL (пример)** | `http://<host>:8000/api/v1/ingest` |
| **Content-Type** | `application/json` |
| **Успешный ответ** | `202 Accepted` |
| **Тело ответа** | `{ "accepted": <количество принятых замеров> }` |

## Аутентификация

Устройство передаёт токен в заголовке:

```
X-Device-Token: <api_token>
```

Токен выдаётся администратором при регистрации датчика в системе (поле `sensors.api_token` в БД). Устройство **не получает** токен автоматически — его нужно прошить или передать при настройке (в т.ч. по BLE).

| Ситуация | Код | Поведение |
|----------|-----|-----------|
| Токен верный | `202` | Замеры записаны в `readings`, у датчика обновлены `last_seen` и `status = online` |
| Токен неверный или отсутствует | `401 Unauthorized` | Данные **не** записываются |

## Тело запроса (JSON)

Один замер **или** массив замеров.

### Один замер

```json
{
  "current_a": 9.12,
  "power_w": 2100.0,
  "ts": "2026-06-30T12:00:00+00:00"
}
```

### Массив замеров

```json
[
  { "current_a": 9.12, "power_w": 2100.0, "ts": "2026-06-30T12:00:00+00:00" },
  { "current_a": 3.80 }
]
```

### Поля

| Поле | Тип | Обязательное | Единицы | Описание |
|------|-----|--------------|---------|----------|
| `current_a` | `number` (float) | **да** | **А (RMS)** | Среднеквадратичный переменный ток фазы. Источник: JSY-MK-194G по Modbus (канал 1). ESP **не** считает ток сам. |
| `power_w` | `number` (float) | нет | **Вт** | Активная мощность канала 1. Источник: JSY-MK-194G. Рекомендуется передавать вместе с `current_a`. |
| `ts` | `string` (ISO 8601) | нет | UTC | Время замера. Если не указано — серверное время (UTC). |

Старые устройства, отправляющие только `current_a`, продолжают работать (`power_w` в БД будет `NULL`).

## Пример curl

```bash
curl -X POST "http://192.168.1.100:8000/api/v1/ingest" \
  -H "Content-Type: application/json" \
  -H "X-Device-Token: YOUR_API_TOKEN_HERE" \
  -d '{"current_a": 9.12, "power_w": 2100.0}'
```

Пакет из нескольких замеров:

```bash
curl -X POST "http://192.168.1.100:8000/api/v1/ingest" \
  -H "Content-Type: application/json" \
  -H "X-Device-Token: YOUR_API_TOKEN_HERE" \
  -d '[{"current_a": 9.12, "power_w": 2100.0}, {"current_a": 3.80, "ts": "2026-06-30T12:00:05+00:00"}]'
```

## Рекомендуемый интервал отправки

**5 секунд** между замерами — штатный режим работы датчика (~12 строк в минуту на устройство).

## Сетевая доступность

Если сервер запущен на рабочей станке разработчика:

- **Не используйте `localhost`** в прошивке ESP — устройство не достучится до вашего ПК по этому адресу.
- Укажите **LAN-IP** машины с сервером (например `192.168.1.100:8000`) или пробросьте порт через туннель (ngrok, Cloudflare Tunnel и т.п.).
- Убедитесь, что порт `8000` доступен в локальной сети (фаервол).

### Production (nginx)

ESP **не поддерживает HTTPS**. В prod ingest идёт по **HTTP на порту 80**:

```
http://<LAN-IP>/api/v1/ingest
```

Пример: `http://192.168.1.100/api/v1/ingest` (не `:8000`, не `https://`).

После перехода на prod **обновите URL на ESP** (BLE-привязка или перепрошивка `secrets.h`). В админке в сниппете датчика URL теперь HTTP автоматически.

## Получение тестового токена (разработка)

Для локальной разработки без реального датчика:

```bash
# из корня репозитория, при запущенной БД
python tools/seed_test_sensor.py
```

Скрипт создаёт тестовую площадку, цех и датчик, выводит `device_id` и `api_token`. Повторный запуск идемпотентен — выводит существующие значения.

Эмулятор ESP:

```bash
python tools/esp_simulator.py --token <api_token> --url http://192.168.1.100:8000/api/v1/ingest
```

## Коды ответов

| Код | Описание |
|-----|----------|
| `202` | Замеры приняты и записаны |
| `401` | Неверный или отсутствующий `X-Device-Token` |
| `422` | Невалидное тело запроса (ошибка валидации JSON) |
| `429` | Превышен rate limit на ingest |

---

## MQTT-телеметрия (альтернатива HTTP)

Backend может принимать данные через **MQTT** (Mosquitto). HTTP остаётся основным транспортом для ESP-прошивки; MQTT — для устройств с MQTT-стеком или эмулятора.

### Запуск брокера

```powershell
docker compose -f docker-compose.prod.yml --profile mqtt up -d mosquitto
```

В `.env`: `MQTT_ENABLED=true`, `MQTT_HOST=mosquitto`.

### Топики

| Топик | QoS | Направление | Описание |
|-------|-----|-------------|----------|
| `sensors/{device_id}/telemetry` | 0 | ESP → backend | Замеры (JSON) |
| `sensors/{device_id}/status` | 1, retain | ESP → backend | Статус online/offline |

`device_id` — поле `sensors.device_id` из админки (не api_token).

### Payload telemetry

```json
{
  "current_a": 0.0,
  "power_w": 0.0,
  "ts": "2026-07-05T10:00:00+00:00"
}
```

Поля совпадают с HTTP ingest. `ts` опционален.

### Last Will and Testament (LWT)

При подключении ESP задаёт **LWT** на топик `sensors/{device_id}/status`:

```json
{"status": "offline"}
```

При неожиданном отключении брокер публикует LWT → backend **мгновенно** помечает датчик offline и шлёт событие по WebSocket.

При успешном подключении опубликуйте retain-сообщение online:

```json
{"status": "online"}
```

### Пример (Python / paho-mqtt)

```python
import json
import paho.mqtt.client as mqtt

device_id = "ESP-001"
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.will_set(
    f"sensors/{device_id}/status",
    json.dumps({"status": "offline"}),
    qos=1,
    retain=True,
)
client.connect("192.168.1.100", 1883)
client.loop_start()
client.publish(
    f"sensors/{device_id}/status",
    json.dumps({"status": "online"}),
    qos=1,
    retain=True,
)
client.publish(
    f"sensors/{device_id}/telemetry",
    json.dumps({"current_a": 0.0, "power_w": 0.0}),
)
```

### Эмулятор

```powershell
pip install paho-mqtt
python tools/mqtt_simulator.py --device-id ESP-001 --host localhost --current 0 --power 0
```

### JSY-MK-194G без напряжения

Реальный ESP без напряжения на входе шлёт **нули** — это штатно:

```json
{"current_a": 0.0, "power_w": 0.0}
```

Система считает датчик online, пока приходят замеры; idle определяется порогами `idle_current_threshold_a` / `idle_power_threshold_w`.
