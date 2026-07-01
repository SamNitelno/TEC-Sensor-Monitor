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

## Прошивка ESP32 (PlatformIO)

```powershell
cd firmware
pio run                  # сборка с FakeCurrentSensor (по умолчанию)
pio run -t upload        # прошивка
pio device monitor       # лог
```

Окружения в `platformio.ini`:
- `esp32dev` — заглушка `FakeCurrentSensor` (компилируется без железа)
- `esp32dev_ina219` — для реального INA219 (когда подключён)

После первой привязки по BLE конфиг хранится в NVS; при следующем включении ESP подключается к Wi-Fi и шлёт телеметрию автоматически.
