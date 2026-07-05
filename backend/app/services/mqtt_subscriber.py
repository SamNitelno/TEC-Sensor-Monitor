import asyncio
import json
from datetime import UTC, datetime

import structlog

from app.core.config import settings
from app.db.session import async_session_factory
from app.repositories import sensor_repository
from app.schemas.ingest import ReadingIn
from app.services import ingest_service
from app.services.downtime_detection_service import handle_mqtt_lwt_offline

logger = structlog.get_logger(__name__)


async def _handle_telemetry(device_id: str, payload: dict) -> None:
    async with async_session_factory() as session:
        sensor = await sensor_repository.get_by_device_id(session, device_id)
        if sensor is None:
            logger.warning("mqtt_unknown_device", device_id=device_id)
            return

        current_a = payload.get("current_a")
        if current_a is None:
            logger.warning("mqtt_missing_current_a", device_id=device_id)
            return

        ts_raw = payload.get("ts")
        ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00")) if ts_raw else None
        reading = ReadingIn(
            current_a=float(current_a),
            power_w=float(payload["power_w"]) if payload.get("power_w") is not None else None,
            ts=ts,
        )
        await ingest_service.ingest_readings(session, sensor, [reading])


async def _handle_status(device_id: str, payload: dict) -> None:
    status = payload.get("status")
    if status != "offline":
        return

    async with async_session_factory() as session:
        sensor = await sensor_repository.get_by_device_id(session, device_id)
        if sensor is None:
            return
        await handle_mqtt_lwt_offline(session, sensor)
        await session.commit()
        logger.info("mqtt_lwt_offline", device_id=device_id, sensor_id=sensor.id)


def _parse_topic(topic: str) -> tuple[str | None, str | None]:
    parts = topic.split("/")
    if len(parts) == 3 and parts[0] == "sensors":
        return parts[1], parts[2]
    return None, None


async def mqtt_subscriber_loop() -> None:
    if not settings.mqtt_enabled:
        return

    try:
        import aiomqtt
    except ImportError:
        logger.error("mqtt_aiomqtt_not_installed")
        return

    backoff = 1.0
    while True:
        try:
            async with aiomqtt.Client(
                hostname=settings.mqtt_host,
                port=settings.mqtt_port,
                username=settings.mqtt_username or None,
                password=settings.mqtt_password or None,
            ) as client:
                await client.subscribe("sensors/+/telemetry")
                await client.subscribe("sensors/+/status")
                logger.info(
                    "mqtt_connected",
                    host=settings.mqtt_host,
                    port=settings.mqtt_port,
                )
                backoff = 1.0

                async for message in client.messages:
                    topic = str(message.topic)
                    device_id, channel = _parse_topic(topic)
                    if device_id is None or channel is None:
                        continue

                    try:
                        payload = json.loads(message.payload.decode())
                    except (json.JSONDecodeError, UnicodeDecodeError):
                        logger.warning("mqtt_invalid_payload", topic=topic)
                        continue

                    if channel == "telemetry":
                        await _handle_telemetry(device_id, payload)
                    elif channel == "status":
                        await _handle_status(device_id, payload)

        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("mqtt_subscriber_error", backoff=backoff)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 60.0)
