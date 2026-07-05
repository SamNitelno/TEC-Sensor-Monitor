# TEC Sensor Monitor

Мониторинг простоя датчиков тока (ТЭК).

## Быстрый старт

```powershell
docker compose up -d
cd frontend
flutter pub get
flutter run -d chrome
```

Вход: `admin` / `admin` или `viewer` / `viewer`.

## Desktop (Windows / macOS / Linux)

Приложение поддерживает нативные desktop-таргеты с BLE-привязкой ESP.

```powershell
cd frontend
flutter pub get
flutter devices
flutter run -d windows
# или: flutter run -d macos / flutter run -d linux
```

Сборка release (выполнять **на целевой ОС**):

```powershell
flutter build windows
flutter build macos
flutter build linux
```

Переопределение URL API:

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://<LAN-IP>:8000
```

### Зависимости BLE на desktop

| ОС | Требования |
|----|------------|
| **Windows** | Bluetooth-адаптер; пакет `flutter_blue_plus_winrt` (WinRT). Windows 10 1809+ |
| **Linux** | [BlueZ](https://www.bluez.org/) + права на D-Bus (`bluetooth` group) |
| **macOS** | Bluetooth в entitlements; разрешение в System Settings |

**Web:** BLE-привязка недоступна — приложение показывает соответствующее сообщение.

## Android-эмулятор (Windows)

1. Запустите backend: `docker compose up -d`
2. Запустите AVD в Android Studio
3. Из каталога `frontend`:

```powershell
flutter devices
flutter run -d <emulator_id>
```

Приложение на Android-эмуляторе автоматически использует `http://10.0.2.2:8000` (alias localhost хоста).

Переопределение URL:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Физический телефон в той же WiFi-сети:

```powershell
flutter run --dart-define=API_BASE_URL=http://<LAN-IP-ПК>:8000
```

## Привязка ESP32

### Вариант A — BLE (рекомендуется для новых устройств)

1. В `.env` задайте `API_PUBLIC_BASE_URL=http://<LAN-IP>:8000` (не localhost)
2. Перезапустите backend: `docker compose up -d`
3. Прошейте ESP: `cd firmware && pio run -t upload` (см. ниже)
4. Войдите как **admin** → **Датчики** → создайте датчик (если ещё нет)
5. **Датчики → BLE** (или иконка Bluetooth в шапке): сканирование → форма Wi-Fi → выбор датчика → привязка
6. Дождитесь статуса **online** на экране успеха

### Вариант B — ручная настройка

1. Создайте датчик в админке → скопируйте **токен** и **сниппет**
2. Передайте на ESP вручную (Wi-Fi + `POST /api/v1/ingest` каждые 5 с)

Контракт: [docs/device-integration.md](docs/device-integration.md)

Проверка без ESP:

```powershell
python tools/esp_simulator.py --token <api_token> --url http://localhost:8000/api/v1/ingest
```

## Прошивка ESP32 (PlatformIO, JSY-MK-194G)

Разводка UART: **RX=GPIO33**, **TX=GPIO32**, 8N1, Modbus-RTU (по умолчанию 4800 baud, адрес 1).

```powershell
cd firmware
pio run -e esp32dev              # без модуля JSY (FakeCurrentSensor)
pio run -e esp32dev_jsy          # реальный JSY + BLE-провижининг
pio run -e esp32dev_jsy_hc         # JSY + Wi-Fi/ток из secrets.h (без BLE)
pio run -e esp32dev_jsy -t upload
pio device monitor
```

**Первичная проверка JSY без BLE:** скопируйте `firmware/src/secrets.h.example` → `secrets.h`, заполните Wi-Fi, LAN-URL ingest и `api_token`, затем `pio run -e esp32dev_jsy_hc -t upload`. Файл `secrets.h` в `.gitignore`.

Параметры в [`firmware/src/hardware_config.h`](firmware/src/hardware_config.h): пины UART, baud, адрес Modbus, `CURRENT_SCALE` (поправка при CT 150A).

**Первичная прошивка** — USB-C (`pio run -t upload`). **BLE** — только для передачи Wi-Fi и токена после прошивки (приложение → Датчики → BLE).

При первом запуске сверьте ток с эталонной нагрузкой (~2 кВт ≈ 9 А при 230 В). При постоянном расхождении задайте `CURRENT_SCALE` в `platformio.ini` (см. комментарий `esp32dev_jsy_scaled`).

## Подтверждение email и телефона

При привязке email или телефона в **Настройки → Профиль** система отправляет код подтверждения. Если меняются оба поля сразу, сначала подтверждается email, затем телефон (SMS).

Настройка отправки — в `.env` (см. `.env.example`):

| Переменная | Назначение |
|------------|------------|
| `VERIFICATION_SMTP_USER` | Почта отправителя |
| `VERIFICATION_SMTP_PASSWORD` | Пароль приложения Gmail |
| `VERIFICATION_SMS_API_ID` | API-ключ [SMS.ru](https://sms.ru/?panel=api) |
| `VERIFICATION_SMS_FROM` | Номер отправителя SMS |
| `VERIFICATION_DELIVERY_MODE` | `log` — коды только в логах, **без** SMTP/SMS; `production` — реальная отправка; `test` — pytest |

Без `VERIFICATION_SMTP_PASSWORD` письма не уходят (код виден в `docker compose logs backend`). Без `VERIFICATION_SMS_API_ID` SMS не отправляются (код в логах).

### Режим `log` (разработка)

В `.env` оставьте `VERIFICATION_DELIVERY_MODE=log`. После «Сохранить профиль» код появится в логе:

```powershell
docker compose logs backend --tail 30
```

Ищите строку `Email verification code for ...` или `SMS verification code for ...`.

### Режим `production` (боевой)

1. Включите двухфакторную аутентификацию в Google-аккаунте.
2. Создайте **пароль приложения**: [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) (тип «Почта», устройство «Другое»).
3. В `.env`: `VERIFICATION_SMTP_PASSWORD=<16 символов без пробелов>`, `VERIFICATION_DELIVERY_MODE=production`.
4. Перезапустите backend: `docker compose up -d`.

Обычный пароль от Gmail для SMTP **не работает** (ошибка `535 Username and Password not accepted`).

## Production (LAN)

Полный prod-стек: nginx + gunicorn + TimescaleDB + WebSocket + TLS.

```powershell
sh infra/tls/generate-self-signed.sh infra/tls
# Настройте .env (JWT_SECRET, POSTGRES_PASSWORD, API_PUBLIC_BASE_URL=https://<LAN-IP>)
.\scripts\build-prod.ps1
```

**Git Bash / Linux / macOS** — не используйте `.\scripts\...` (это синтаксис PowerShell):

```bash
sh scripts/build-prod.sh
```

Подробнее: [docs/production.md](docs/production.md), [docs/device-integration.md](docs/device-integration.md) (MQTT).

Realtime: дашборд обновляется по WebSocket `/ws` без polling. MQTT (опционально): `docker compose -f docker-compose.prod.yml --profile mqtt up -d`.
