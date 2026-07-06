# TEC Sensor Monitor

Система мониторинга простоя и потребления тока на производстве. Датчики **ESP32 + JSY-MK-194G** отправляют телеметрию на backend, данные хранятся в **TimescaleDB**, дашборд обновляется в реальном времени по **WebSocket**.

Поддерживаемые клиенты: **Web**, **Windows / macOS / Linux (desktop)**, **Android**. BLE-привязка ESP доступна на native-клиентах (не в браузере).

> **LAN-IP в примерах** — `192.168.1.100` условный адрес. Замените на IPv4 вашего сервера (`ipconfig` / `ifconfig`). Реальные секреты — только в `.env` (файл в `.gitignore`, не коммитить).

---

## Содержание

- [Архитектура](#архитектура)
- [Требования](#требования)
- [Быстрый старт (разработка)](#быстрый-старт-разработка)
- [Конфигурация (.env)](#конфигурация-env)
- [Роли и доступ](#роли-и-доступ)
- [Production (LAN)](#production-lan)
- [Клиенты по платформам](#клиенты-по-платформам)
  - [Web](#web)
  - [Windows / macOS / Linux](#windows--macos--linux)
  - [Android](#android)
- [ESP32: прошивка и привязка](#esp32-прошивка-и-привязка)
  - [Железо и UART](#железо-и-uart)
  - [Сборка и прошивка](#сборка-и-прошивка)
  - [Привязка по BLE](#привязка-по-ble)
  - [Ручная настройка (secrets.h)](#ручная-настройка-secretsh)
  - [Смена URL / ротация токена](#смена-url--ротация-токена)
- [Проверка без ESP](#проверка-без-esp)
- [Безопасность](#безопасность)
- [Тестирование](#тестирование)
- [Документация](#документация)
- [Устранение неполадок](#устранение-неполадок)

---

## Архитектура

### Development

```
┌─────────────┐     HTTP :8000      ┌──────────────┐     ┌─────────────┐
│ Flutter     │ ──────────────────► │   Backend    │ ──► │ TimescaleDB │
│ (run/dev)   │     /api/v1, /ws    │   uvicorn    │     │   :5432     │
└─────────────┘                     └──────────────┘     └─────────────┘
                                           ▲
┌─────────────┐     HTTP :8000             │
│ ESP32       │ ─ POST /api/v1/ingest ─────┘
│ X-Device-Token
└─────────────┘
```

### Production (LAN)

```
┌─────────────┐  HTTPS :443   ┌─────────────────────────────────────────┐
│ Браузер /   │ ────────────► │ nginx                                   │
│ Flutter app │               │  /          → Flutter Web (static)        │
└─────────────┘               │  /api/*     → gunicorn → backend:8000   │
                              │  /ws        → WebSocket (JWT)           │
                              └─────────────────────────────────────────┘
                                           ▲
┌─────────────┐  HTTP :80 (только ingest)  │
│ ESP32       │ ─ POST /api/v1/ingest ───────┘
│ (без TLS)   │   + GET /health
└─────────────┘

Порт 80: только /api/v1/ingest и /health.
Остальной /api/* → 301 на HTTPS (логин и JWT не идут по cleartext).
```

### Поток данных

```mermaid
flowchart LR
  subgraph device [Устройство]
    JSY[JSY-MK-194G Modbus]
    ESP[ESP32]
    JSY --> ESP
  end

  subgraph server [Сервер]
    NG[nginx]
    BE[FastAPI backend]
    DB[(TimescaleDB)]
    NG --> BE --> DB
  end

  subgraph clients [Клиенты]
    WEB[Flutter Web]
    APP[Desktop / Android]
  end

  ESP -->|HTTP ingest каждые 5 с| NG
  WEB -->|HTTPS + WSS| NG
  APP -->|HTTPS + WSS| NG
  APP -.->|BLE Wi-Fi + token| ESP
```

---

## Требования

| Компонент | Версия / инструмент |
|-----------|---------------------|
| Docker + Compose | для backend и prod-стека |
| Flutter SDK | ^3.6 (Web, Windows, Android, macOS, Linux) |
| PlatformIO | прошивка ESP32 |
| Python 3.12+ | эмуляторы, `prepare_esp_secrets.py`, pytest |
| mkcert | рекомендуется для TLS на native-клиентах в LAN |

---

## Быстрый старт (разработка)

### 1. Конфигурация

```powershell
copy .env.example .env
```

Для локальной разработки в `.env` достаточно:

```env
APP_ENV=development
POSTGRES_PASSWORD=tek_secret
DATABASE_URL=postgresql+asyncpg://tek:tek_secret@timescaledb:5432/tek_sensor
JWT_SECRET=dev-jwt-secret-min-32-characters-long
ADMIN_LOGIN=admin
ADMIN_PASSWORD=admin
VIEWER_LOGIN=viewer
VIEWER_PASSWORD=viewer
ALLOW_PUBLIC_REGISTRATION=true
API_PUBLIC_BASE_URL=http://localhost:8000
```

Пароли `admin` / `viewer` синхронизируются при старте backend (bootstrap).

### 2. Backend

```powershell
docker compose up -d
```

- API: `http://localhost:8000`
- Swagger (только dev): `http://localhost:8000/docs`
- Health: `http://localhost:8000/health`

### 3. Frontend

```powershell
cd frontend
flutter pub get
flutter run -d chrome
# или: flutter run -d windows
```

Вход: логин и пароль из `.env` (`admin` / `viewer` в dev-конфиге выше).

---

## Конфигурация (.env)

Полный список переменных — в [`.env.example`](.env.example). Ключевые:

| Переменная | Назначение |
|------------|------------|
| `APP_ENV` | `development` или `production` |
| `JWT_SECRET` | Подпись JWT, WebSocket, pepper для хеша токенов устройств |
| `JWT_EXPIRE_MINUTES` | TTL сессии (по умолчанию **720** = 12 ч) |
| `ADMIN_PASSWORD` / `VIEWER_PASSWORD` | Учётные записи bootstrap (обязательны, без слабых дефолтов в prod) |
| `ALLOW_PUBLIC_REGISTRATION` | `false` в prod — самостоятельная регистрация и OTP отключены |
| `API_PUBLIC_BASE_URL` | Публичный URL для клиентов и сниппетов (`https://<LAN-IP>` в prod) |
| `DEVICE_INGEST_BASE_URL` | URL ingest для ESP (**HTTP**, без порта 8000). Пусто → автоматически `http://` из HTTPS base |
| `CORS_ORIGINS` | В prod: список origins через запятую |
| `WEB_CONCURRENCY` | Gunicorn workers (**1** — для WebSocket без Redis) |

---

## Роли и доступ

| Роль | Возможности |
|------|-------------|
| **admin** | Датчики, группы (цеха/площадки), пользователи, BLE-привязка, promote/demote |
| **viewer** | Дашборд, графики, уведомления, настройки профиля |

### Пользователи в production

- Публичная регистрация **выключена** (`ALLOW_PUBLIC_REGISTRATION=false`).
- Новых пользователей создаёт **admin** → раздел **Пользователи**.
- OTP/email/SMS-подтверждение — только dev-режим за флагом регистрации.

### Навигация в приложении

| Раздел | Путь | Кто видит |
|--------|------|-----------|
| Мониторинг (дашборд) | `/` | все |
| Датчики | `/sensors` | admin |
| Группы | `/groups` | admin |
| Пользователи | `/users` | admin |
| BLE-привязка | `/provisioning` | admin, только native |
| Настройки | `/settings` | все |

BLE также доступен: иконка Bluetooth в шапке (admin) или кнопка **BLE** на экране **Датчики**.

---

## Production (LAN)

### 1. Секреты

Сгенерируйте сильные значения и запишите в `.env`:

```powershell
python -c "import secrets; print('JWT_SECRET='+secrets.token_urlsafe(48)); print('ADMIN_PASSWORD='+secrets.token_urlsafe(16)+'A1'); print('VIEWER_PASSWORD='+secrets.token_urlsafe(16)+'B2')"
```

Обязательно задайте:

```env
APP_ENV=production
ALLOW_PUBLIC_REGISTRATION=false
API_PUBLIC_BASE_URL=https://192.168.1.100
DEVICE_INGEST_BASE_URL=http://192.168.1.100
CORS_ORIGINS=https://192.168.1.100
```

При `APP_ENV=production` backend **не стартует** со слабыми секретами (`change-me`, `admin`, `viewer` и т.п.).

### 2. TLS-сертификаты

**Web (браузер)** переживёт self-signed с одноразовым предупреждением.

**Android / Windows desktop** отвергают self-signed без доверенного CA. Используйте **mkcert**:

```powershell
# Установите mkcert: https://github.com/FiloSottile/mkcert
.\scripts\generate-mkcert.ps1 -LanIp 192.168.1.100
```

Установите корневой CA mkcert на каждое клиентское устройство:

```powershell
mkcert -CAROOT   # путь к rootCA.pem — импортировать в «Доверенные корневые ЦС»
```

Альтернатива (только Web): `sh infra/tls/generate-self-signed.sh infra/tls`

### 3. Сборка и запуск

```powershell
.\scripts\build-prod.ps1
# или с явным URL:
.\scripts\build-prod.ps1 -ApiBaseUrl "https://192.168.1.100"
```

Скрипт: `flutter build web` → `docker compose -f docker-compose.prod.yml up -d --build`.

**Git Bash / Linux / macOS:**

```bash
sh scripts/build-prod.sh
```

Откройте `https://<LAN-IP>/`.

### 4. Проверка prod

```powershell
# Health (HTTP, для мониторинга)
curl http://192.168.1.100/health

# Ingest (замените TOKEN)
curl -X POST http://192.168.1.100/api/v1/ingest `
  -H "Content-Type: application/json" `
  -H "X-Device-Token: TOKEN" `
  -d '{"current_a": 0.01}'
# Ожидается: 202 {"accepted":1}
```

### 5. MQTT (опционально)

```powershell
# Создайте infra/mosquitto/passwd (mosquitto_passwd)
docker compose -f docker-compose.prod.yml --profile mqtt up -d
```

В `.env`: `MQTT_ENABLED=true`, `MQTT_USERNAME`, `MQTT_PASSWORD`. Порт **1883** не пробрасывается на хост в prod — только внутренняя docker-сеть.

Подробнее: [docs/device-integration.md](docs/device-integration.md), [docs/production.md](docs/production.md).

---

## Клиенты по платформам

Адрес сервера задаётся **в приложении**: **Настройки → Адрес сервера** (сохраняется на устройстве). Один раз ввёл — приложение помнит; при смене сети или IP просто меняешь адрес в настройках, пересобирать не нужно.

Приоритет источников: сохранённый в настройках адрес → `--dart-define=API_BASE_URL=...` (опциональный дефолт для сборки) → платформенный дефолт (`http://localhost:8000`, для Android-эмулятора `http://10.0.2.2:8000`). То есть `--dart-define` в командах ниже необязателен — он лишь задаёт значение по умолчанию, которое можно переопределить в настройках.

| Режим | API URL | WebSocket |
|-------|---------|-----------|
| Dev, localhost | `http://localhost:8000` | `ws://...` |
| Dev, LAN | `http://<LAN-IP>:8000` | `ws://...` |
| Prod | `https://<LAN-IP>` | `wss://...` |

---

### Web

**Development** — hot reload через Flutter:

```powershell
cd frontend
flutter run -d chrome
# по умолчанию http://localhost:8000; другой адрес — в Настройках приложения
```

**Production** — статика через nginx, API same-origin (`https://<LAN-IP>/api/v1`).

| Функция | Web |
|---------|-----|
| Дашборд, графики, WS | да |
| Уведомления (bell) | да |
| BLE-привязка ESP | **нет** — используйте телефон или desktop |

---

### Windows / macOS / Linux

Native desktop с полной поддержкой BLE.

```powershell
cd frontend
flutter pub get
flutter devices
flutter run -d windows
# flutter run -d macos
# flutter run -d linux
```

**Release-сборка** (на целевой ОС):

```powershell
flutter build windows
# flutter build macos
# flutter build linux
```

Адрес сервера вводится в приложении (**Настройки → Адрес сервера**) при первом запуске — пересобирать под конкретную сеть не нужно. Чтобы зашить дефолтный адрес прямо в сборку, добавь `--dart-define=API_BASE_URL=https://192.168.1.100`.

Артефакты:

| ОС | Путь |
|----|------|
| Windows | `frontend/build/windows/x64/runner/Release/` |
| macOS | `frontend/build/macos/Build/Products/Release/` |
| Linux | `frontend/build/linux/x64/release/bundle/` |

#### BLE на desktop

| ОС | Требования |
|----|------------|
| **Windows** | Bluetooth-адаптер, Windows 10 1809+, пакет `flutter_blue_plus_winrt` |
| **Linux** | [BlueZ](https://www.bluez.org/), пользователь в группе `bluetooth` |
| **macOS** | Bluetooth в entitlements, разрешение в System Settings |

**Prod + HTTPS:** установите mkcert CA на машине с desktop-приложением, иначе TLS-рукопожатие не пройдёт.

---

### Android

#### Эмулятор (AVD)

Backend на хосте, эмулятор обращается к `10.0.2.2` (alias localhost хоста):

```powershell
docker compose up -d
cd frontend
flutter run -d <emulator_id>
# URL по умолчанию для Android: http://10.0.2.2:8000
```

Другой адрес — в **Настройках** приложения, либо явным override при запуске:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

#### Физический телефон (Wi‑Fi)

Телефон и сервер в одной LAN. Запусти обычную сборку и укажи LAN-адрес сервера (`https://<LAN-IP>`) в **Настройках** приложения:

```powershell
flutter run
# адрес сервера → Настройки приложения; либо зашить дефолт: --dart-define=API_BASE_URL=https://192.168.1.100
```

**Prod:** установите mkcert CA на телефон (Android → Настройки → Безопасность → Установить сертификат).

#### Release APK

```powershell
flutter build apk --release
```

APK: `frontend/build/app/outputs/flutter-apk/app-release.apk`. Адрес сервера задаётся в **Настройках** приложения при первом запуске (на физическом телефоне — LAN-IP сервера, `https://<LAN-IP>`). Опционально зашить дефолт: `--dart-define=API_BASE_URL=https://192.168.1.100`.

| Функция | Android |
|---------|---------|
| Дашборд, WS, уведомления | да |
| BLE-привязка ESP | да |
| Local notifications | да (при простое / offline) |

---

## ESP32: прошивка и привязка

Прошивка: **PlatformIO**, плата **ESP32-WROOM-32**, датчик тока **JSY-MK-194G** (Modbus-RTU).

### Железо и UART

| Сигнал | ESP32 GPIO | Примечание |
|--------|------------|------------|
| RX (от модуля TX) | **GPIO 33** | зелёный |
| TX (к модулю RX) | **GPIO 32** | зелёный |
| Modbus | 8N1, **4800 baud**, адрес **1** | настраивается в `hardware_config.h` |

Параметры: [`firmware/src/hardware_config.h`](firmware/src/hardware_config.h) — пины, baud, `CURRENT_SCALE` (поправка под CT 150A), канал измерения.

### Сборка и прошивка

```powershell
cd firmware
pio pkg install          # первый раз
pio run -e esp32dev              # без JSY (FakeCurrentSensor, тест логики)
pio run -e esp32dev_jsy          # реальный JSY + BLE-провижининг (штатный режим)
pio run -e esp32dev_jsy -t upload
pio device monitor                 # лог 115200
```

| Окружение | Назначение |
|-----------|------------|
| `esp32dev` | Эмуляция тока, без железа JSY |
| `esp32dev_jsy` | **Основной** — JSY + BLE, Wi‑Fi из NVS после привязки |
| `esp32dev_jsy_hc` | Wi‑Fi + URL + токен из `secrets.h` (первая отладка без BLE) |
| `esp32dev_jsy_update_url` | Только обновить ingest URL в NVS (Wi‑Fi сохраняется) |
| `esp32dev_jsy_wipe` | Однократный сброс NVS при загрузке |

**Первичная прошивка** — USB-C (`pio run -t upload`). Дальнейшая настройка Wi‑Fi и токена — через **BLE** или `secrets.h`.

Калибровка: при CT 150A на канале 50/100A задан `CURRENT_SCALE=11.976` в `platformio.ini`. Сверьте с эталонной нагрузкой (~2 кВт ≈ 9 А при 230 В).

### Привязка по BLE

BLE доступен **только admin** и **только на native-клиентах** (Android, Windows, macOS, Linux). В Web — сообщение «используйте телефон или desktop».

```mermaid
sequenceDiagram
  participant Admin as Admin app
  participant ESP as ESP32 (BLE)
  participant API as Backend

  Admin->>API: Создать датчик (Датчики → +)
  API-->>Admin: api_token (показывается один раз)
  Admin->>Admin: Датчики → BLE (или иконка BT в шапке)
  Admin->>ESP: Сканирование → выбор устройства
  Admin->>ESP: Wi-Fi SSID, пароль, ingest URL, token
  ESP->>ESP: Сохранение в NVS, подключение к Wi-Fi
  loop каждые 5 с
    ESP->>API: POST /api/v1/ingest (X-Device-Token)
  end
  Admin->>API: Опрос статуса датчика
  API-->>Admin: status = online → успех
```

#### Пошагово

1. В `.env` задайте `API_PUBLIC_BASE_URL` и `DEVICE_INGEST_BASE_URL` с **LAN-IP** (не `localhost`).
2. Перезапустите backend / prod-стек.
3. Прошейте ESP: `pio run -e esp32dev_jsy -t upload`.
4. Войдите как **admin**.
5. **Датчики → +** — создайте датчик (имя, Device ID). **Сохраните токен** из диалога — он больше не отображается (в БД хранится хеш).
6. **Датчики → BLE** (или иконка Bluetooth в шапке):
   - сканирование → выбор ESP;
   - SSID и пароль Wi‑Fi;
   - выбор датчика из списка (подставятся ingest URL и токен);
   - **Привязать** → дождитесь **online** (~90 с).
7. На дашборде появятся live-графики (WebSocket).

**Production ingest URL для ESP:** `http://<LAN-IP>/api/v1/ingest` (порт 80, **без HTTPS**). ESP не поддерживает TLS.

### Ручная настройка (secrets.h)

Если BLE недоступен или нужна первая отладка на столе:

```powershell
copy firmware\src\secrets.h.example firmware\src\secrets.h
```

Заполните `secrets.h`:

```cpp
#define HC_WIFI_SSID "MY_WIFI"
#define HC_WIFI_PASSWORD "MY_WIFI_PASSWORD"
#define HC_SERVER_URL "http://192.168.1.100/api/v1/ingest"
#define HC_DEVICE_TOKEN "PASTE_TOKEN_FROM_ADMIN_UI"
```

```powershell
pio run -e esp32dev_jsy_hc -t upload
```

Файл `secrets.h` в `.gitignore` — не коммитить.

Автогенерация из API (если токен ещё известен или задан `DEVICE_TOKEN` в `.env`):

```powershell
python tools/prepare_esp_secrets.py
pio run -e esp32dev_jsy_hc -t upload
```

### Смена URL / ротация токена

Токены устройств в БД **хешируются**. Plaintext показывается **один раз** при создании датчика.

| Ситуация | Действие |
|----------|----------|
| Новый ESP | Создать датчик → скопировать токен → BLE или `secrets.h` |
| Потерян токен / повторная привязка | Ротация через API (admin JWT): |
| Переход dev → prod (смена URL) | BLE-привязка с новым URL **или** `esp32dev_jsy_update_url` + `secrets.h` с новым `HC_SERVER_URL` |

**Ротация токена (API):**

```powershell
curl -X POST "https://192.168.1.100/api/v1/sensors/1/rotate-token" `
  -H "Authorization: Bearer <ADMIN_JWT>" `
  -k
# Ответ: новый api_token + ingest_url → передать на ESP по BLE
```

Контракт ingest: [docs/device-integration.md](docs/device-integration.md).

---

## Проверка без ESP

```powershell
# Тестовый датчик в БД (dev)
python tools/seed_test_sensor.py

# Эмулятор HTTP-телеметрии
python tools/esp_simulator.py --token <api_token> --url http://localhost:8000/api/v1/ingest

# MQTT-эмулятор (если включён профиль mqtt)
python tools/mqtt_simulator.py --device-id ESP-001 --host localhost
```

---

## Безопасность

| Мера | Описание |
|------|----------|
| TLS | HTTPS для клиентов; mkcert CA на native-устройствах |
| HTTP :80 | Только ingest + health; API/auth → redirect на HTTPS |
| Токены устройств | SHA-256 + pepper (`JWT_SECRET`); ESP шлёт plaintext |
| JWT | TTL 12 ч (`JWT_EXPIRE_MINUTES=720`), без refresh |
| Регистрация | Выключена в prod; пользователи через admin |
| Rate limits | login, register, verify, ingest |
| Логи | Без OTP, токенов, паролей, api_id SMS |
| MQTT | `allow_anonymous false`; порт не на хост в prod |
| Postgres | Порт не пробрасывается наружу в prod-compose |

At-rest шифрование PostgreSQL **не используется** — threat model LAN-сниффинг; для физической защиты диска — BitLocker на хосте.

---

## Тестирование

```powershell
# Backend (в docker, с монтированием tests)
docker compose run --rm --no-deps backend sh -c "pip install -q pytest pytest-asyncio httpx && python -m pytest tests/ -q"

# Flutter widget-тест (баннеры дашборда)
cd frontend
flutter test test/dashboard_alerts_bar_test.dart
```

Ручной чеклист prod: web / Android / Windows login, BLE (admin), роли, уведомления, WS live, ingest 202, баннеры offline на мобильном layout.

---

## Документация

| Файл | Содержание |
|------|------------|
| [docs/device-integration.md](docs/device-integration.md) | HTTP/MQTT ingest, поля JSON, коды ответов |
| [docs/production.md](docs/production.md) | Prod-стек, TimescaleDB, WebSocket, Let's Encrypt |

---

## Устранение неполадок

| Симптом | Решение |
|---------|---------|
| ESP не online | Проверьте Wi‑Fi, ingest URL (`http://`, не `https://`), `X-Device-Token`, LAN-доступность порта 80 |
| `Invalid device token` | Токен не совпадает с БД → ротация или повторная BLE с актуальным токеном |
| Клиент не видит сервер (desktop/Android) | Проверьте **Настройки → Адрес сервера**: в prod `https://<LAN-IP>` (без `:8000`), клиент и сервер в одной LAN |
| Android/Windows не подключается к HTTPS | Установите mkcert CA; self-signed без CA не работает |
| BLE не находит ESP | ESP прошит `esp32dev_jsy`, Bluetooth включён, расстояние < 5 м |
| BLE в браузере | Недоступен by design — desktop или Android |
| `401` при login | Пароли из `.env` (bootstrap sync); в prod не `admin/admin` |
| WebSocket не обновляет графики | Проверьте WSS, JWT не истёк, `WEB_CONCURRENCY=1` |
| Регистрация 404 в prod | Ожидаемо — создавайте пользователей через admin |

---

## Структура репозитория

```
├── backend/           FastAPI, Alembic, pytest
├── frontend/          Flutter (Web + desktop + Android)
├── firmware/          ESP32 PlatformIO
├── infra/             nginx, mosquitto, TLS
├── scripts/           build-prod, generate-mkcert
├── tools/             эмуляторы, prepare_esp_secrets
├── docs/              интеграция устройств, production
├── docker-compose.yml       dev
└── docker-compose.prod.yml  prod (nginx + gunicorn)
```
