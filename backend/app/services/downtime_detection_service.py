import asyncio
import logging
import statistics
from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import async_session_factory
from app.models.downtime_event import DowntimeType
from app.models.reading import Reading
from app.models.sensor import Sensor, SensorStatus
from app.repositories import (
    downtime_repository,
    reading_repository,
    sensor_repository,
)
from app.schemas.ingest import ReadingIn
from app.services import notification_service
from app.services.sensor_status import is_sensor_online
from app.services.ws_manager import ws_manager

logger = logging.getLogger(__name__)

_idle_pending_since: dict[int, datetime] = {}


def _as_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _idle_power_threshold(sensor: Sensor) -> float:
    return (
        sensor.idle_power_threshold_w
        if sensor.idle_power_threshold_w is not None
        else settings.default_idle_power_threshold_w
    )


def _idle_current_threshold(sensor: Sensor) -> float:
    return (
        sensor.idle_current_threshold_a
        if sensor.idle_current_threshold_a is not None
        else settings.default_idle_current_threshold_a
    )


def _idle_duration(sensor: Sensor) -> int:
    return (
        sensor.idle_duration_seconds
        if sensor.idle_duration_seconds is not None
        else settings.default_idle_duration_seconds
    )


def _is_sample_idle(
    sensor: Sensor,
    current_a: float,
    power_w: float | None,
) -> bool:
    """Idle when current is near zero; power is checked only if current is low."""
    current_thr = _idle_current_threshold(sensor)
    if current_a >= current_thr:
        return False
    if power_w is not None:
        return power_w < _idle_power_threshold(sensor)
    return current_a < current_thr


def _is_below_idle_threshold(sensor: Sensor, readings: list[Reading]) -> bool:
    if not readings:
        return False
    window = readings[-settings.downtime_smoothing_samples :]
    current_median = statistics.median([r.current_a for r in window])
    if current_median >= _idle_current_threshold(sensor):
        return False
    power_values = [r.power_w for r in window if r.power_w is not None]
    if power_values:
        return statistics.median(power_values) < _idle_power_threshold(sensor)
    return current_median < _idle_current_threshold(sensor)


def _is_ingest_idle(sensor: Sensor, reading: ReadingIn) -> bool:
    return _is_sample_idle(sensor, reading.current_a, reading.power_w)


def _is_db_reading_idle(sensor: Sensor, reading: Reading) -> bool:
    return _is_sample_idle(sensor, reading.current_a, reading.power_w)


def _is_idle_state(sensor: Sensor, readings: list[Reading]) -> bool:
    """Idle when smoothed window and latest sample both indicate idle."""
    if not readings:
        return False
    return _is_below_idle_threshold(sensor, readings) and _is_db_reading_idle(
        sensor, readings[-1]
    )


async def _notify_sensor_offline(
    session: AsyncSession,
    sensor: Sensor,
    started_at: datetime,
) -> None:
    await notification_service.notify_downtime_event(
        session,
        sensor=sensor,
        event_type=DowntimeType.offline,
        started_at=started_at,
    )


async def _notify_sensor_idle(
    session: AsyncSession,
    sensor: Sensor,
    started_at: datetime,
) -> None:
    await notification_service.notify_downtime_event(
        session,
        sensor=sensor,
        event_type=DowntimeType.idle,
        started_at=started_at,
    )


async def handle_mqtt_lwt_offline(session: AsyncSession, sensor: Sensor) -> None:
    """Mark sensor offline immediately on MQTT Last Will."""
    now = datetime.now(UTC)
    await sensor_repository.set_status(session, sensor.id, SensorStatus.offline)
    open_event = await downtime_repository.get_open_event(
        session,
        sensor.id,
        DowntimeType.offline,
    )
    if open_event is None:
        started_at = _as_utc(sensor.last_seen) if sensor.last_seen else now
        await downtime_repository.create_event(
            session,
            sensor_id=sensor.id,
            event_type=DowntimeType.offline,
            started_at=started_at,
        )
        await _notify_sensor_offline(session, sensor, started_at)
        logger.info("Sensor %s offline (MQTT LWT)", sensor.name)
    await ws_manager.broadcast_sensor_status(
        sensor_id=sensor.id,
        status=SensorStatus.offline,
        last_seen=sensor.last_seen,
    )


async def handle_telemetry_resumed(
    session: AsyncSession,
    sensor_id: int,
    resumed_at: datetime,
) -> None:
    """Close all open offline events when ingest resumes."""
    open_events = await downtime_repository.list_open_events(
        session,
        sensor_id,
        DowntimeType.offline,
    )
    for event in open_events:
        await downtime_repository.close_event(session, event, resumed_at)


async def handle_telemetry_activity(
    session: AsyncSession,
    sensor: Sensor,
    readings: list[ReadingIn],
    at: datetime,
) -> None:
    """Close offline/idle downtime as soon as active telemetry arrives."""
    await handle_telemetry_resumed(session, sensor.id, at)
    if not readings:
        return

    last = readings[-1]
    if _is_ingest_idle(sensor, last):
        return

    _idle_pending_since.pop(sensor.id, None)
    open_idle = await downtime_repository.list_open_events(
        session,
        sensor.id,
        DowntimeType.idle,
    )
    for event in open_idle:
        await downtime_repository.close_event(session, event, at)
        logger.info("Sensor %s active (ingest), idle event closed", sensor.name)


async def _process_offline(
    session: AsyncSession,
    sensor: Sensor,
    now: datetime,
) -> None:
    online = is_sensor_online(sensor, now=now)
    open_event = await downtime_repository.get_open_event(
        session,
        sensor.id,
        DowntimeType.offline,
    )

    if not online:
        if sensor.status != SensorStatus.offline:
            await sensor_repository.set_status(session, sensor.id, SensorStatus.offline)
            await ws_manager.broadcast_sensor_status(
                sensor_id=sensor.id,
                status=SensorStatus.offline,
                last_seen=sensor.last_seen,
            )
        if open_event is None:
            started_at = _as_utc(sensor.last_seen) if sensor.last_seen else now
            await downtime_repository.create_event(
                session,
                sensor_id=sensor.id,
                event_type=DowntimeType.offline,
                started_at=started_at,
            )
            await _notify_sensor_offline(session, sensor, started_at)
            logger.info("Sensor %s offline, downtime event opened", sensor.name)
        return

    if sensor.status != SensorStatus.online:
        await sensor_repository.set_status(session, sensor.id, SensorStatus.online)
        await ws_manager.broadcast_sensor_status(
            sensor_id=sensor.id,
            status=SensorStatus.online,
            last_seen=sensor.last_seen,
        )
    if open_event is not None:
        await downtime_repository.close_event(session, open_event, now)
        logger.info("Sensor %s online, offline event closed", sensor.name)


async def _process_idle(
    session: AsyncSession,
    sensor: Sensor,
    now: datetime,
) -> None:
    if not is_sensor_online(sensor, now=now):
        _idle_pending_since.pop(sensor.id, None)
        return

    readings = await reading_repository.get_recent_readings(
        session,
        sensor.id,
        limit=max(settings.downtime_smoothing_samples, 3),
    )
    if not readings:
        return

    open_idle = await downtime_repository.get_open_event(
        session,
        sensor.id,
        DowntimeType.idle,
    )
    idle_now = _is_idle_state(sensor, readings)
    duration_sec = _idle_duration(sensor)

    if idle_now:
        pending = _idle_pending_since.get(sensor.id)
        if pending is None:
            _idle_pending_since[sensor.id] = now
            return
        if (now - pending).total_seconds() < duration_sec:
            return
        if open_idle is None:
            await downtime_repository.create_event(
                session,
                sensor_id=sensor.id,
                event_type=DowntimeType.idle,
                started_at=pending,
            )
            await _notify_sensor_idle(session, sensor, pending)
            logger.info("Sensor %s idle, downtime event opened", sensor.name)
        return

    _idle_pending_since.pop(sensor.id, None)
    if open_idle is not None:
        await downtime_repository.close_event(session, open_idle, now)
        logger.info("Sensor %s active, idle event closed", sensor.name)


async def run_downtime_detection_cycle(session: AsyncSession) -> None:
    now = datetime.now(UTC)
    sensors = await sensor_repository.list_all(session)
    for sensor in sensors:
        await _process_offline(session, sensor, now)
        await _process_idle(session, sensor, now)
    await session.commit()


async def downtime_worker_loop() -> None:
    while True:
        try:
            async with async_session_factory() as session:
                await run_downtime_detection_cycle(session)
        except Exception:
            logger.exception("Downtime worker failed")
        await asyncio.sleep(settings.downtime_worker_interval_seconds)
