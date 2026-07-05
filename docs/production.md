# Production deployment

## Быстрый старт (LAN)

```powershell
# 1. TLS (self-signed для локальной сети)
sh infra/tls/generate-self-signed.sh infra/tls

# 2. Настройте .env (скопируйте из .env.example)
#    API_PUBLIC_BASE_URL=https://<LAN-IP>
#    JWT_SECRET=<длинная случайная строка>
#    POSTGRES_PASSWORD=<сильный пароль>

# 3. Сборка Flutter Web + запуск prod-стека
#    (Flutter собирается на хосте — Docker не тянет ghcr.io)

# PowerShell (Windows):
#   .\scripts\build-prod.ps1

# Git Bash / Linux / macOS:
sh scripts/build-prod.sh

# Или вручную:
# cd frontend
# flutter build web --release --dart-define=API_BASE_URL=https://<LAN-IP>
# cd ..
# docker compose -f docker-compose.prod.yml up -d --build

# 4. (Опционально) MQTT
docker compose -f docker-compose.prod.yml --profile mqtt up -d
# В .env: MQTT_ENABLED=true
```

Откройте `https://<LAN-IP>/` — Flutter Web через nginx, API на `/api/v1`, WebSocket на `/ws`.

Браузер предупредит о self-signed сертификате — добавьте исключение для LAN.

## Архитектура

```
[ESP/браузер] → nginx:443
                 ├─ /          → Flutter Web (static)
                 ├─ /api/*     → gunicorn+uvicorn (backend:8000)
                 └─ /ws        → WebSocket (backend:8000)

[ESP MQTT] → mosquitto:1883 → backend subscriber → TimescaleDB
```

## TLS

| Этап | Сертификат |
|------|------------|
| **Сейчас (LAN)** | Self-signed: `infra/tls/generate-self-signed.sh` |
| **Публичный домен** | [Let's Encrypt](https://letsencrypt.org/) + certbot |

### Переход на Let's Encrypt

1. Укажите DNS A-запись на сервер.
2. Временно замените nginx `server` блок на HTTP-01 challenge (certbot).
3. Получите сертификат: `certbot certonly --webroot -w /var/www/certbot -d sensor.example.com`
4. Смонтируйте `/etc/letsencrypt/live/sensor.example.com/` в nginx вместо `infra/tls/`.
5. Настройте автообновление: `certbot renew` в cron/systemd timer.

## Переменные окружения

Секреты **только** из `.env` (не коммитить). Ключевые:

| Переменная | Назначение |
|------------|------------|
| `JWT_SECRET` | Подпись JWT и WebSocket auth |
| `POSTGRES_PASSWORD` | БД |
| `API_PUBLIC_BASE_URL` | URL для ESP-сниппетов и Flutter build |
| `CORS_ORIGINS` | Разрешённые origins (через запятую) |
| `MQTT_ENABLED` | Включить MQTT-подписчик backend |
| `WEB_CONCURRENCY` | Gunicorn workers (1 для WS без Redis) |

## TimescaleDB

Миграция `012` настраивает:

- Continuous aggregates с `current_a` **и** `power_w` (minute/hour/day)
- Сжатие чанков старше 7 дней
- Retention 365 дней

Проверка политик:

```sql
SELECT * FROM timescaledb_information.jobs
WHERE proc_name IN ('policy_compression', 'policy_retention', 'policy_refresh_continuous_aggregate');
```

## Realtime WebSocket

- Эндпоинт: `wss://<host>/ws?token=<JWT>`
- События: `reading`, `sensor_status`, `ping`
- Frontend подключается после логина, графики обновляются без polling

## Dev vs Prod

| | Dev (`docker compose up`) | Prod (`docker-compose.prod.yml`) |
|--|---------------------------|----------------------------------|
| Backend | uvicorn --reload | gunicorn + uvicorn workers |
| Frontend | `flutter run` | nginx static build |
| TLS | нет | self-signed / Let's Encrypt |
| Порты | 8000, 5432 | 80, 443 |
