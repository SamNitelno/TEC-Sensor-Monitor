from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sensor import Sensor
from app.repositories import reading_repository, sensor_repository
from app.schemas.ingest import ReadingIn
from app.services.downtime_detection_service import handle_telemetry_activity

_MAX_DEVICE_CLOCK_SKEW = timedelta(seconds=30)
_MIN_VALID_TIME = datetime(2024, 1, 1, tzinfo=UTC)


def _clamp_device_timestamp(ts: datetime, server_now: datetime) -> datetime:
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=UTC)
    else:
        ts = ts.astimezone(UTC)
    if ts < _MIN_VALID_TIME:
        return server_now
    if ts > server_now + _MAX_DEVICE_CLOCK_SKEW:
        return server_now
    return ts


def _resolve_timestamps(readings: list[ReadingIn]) -> list[datetime]:
    server_now = datetime.now(UTC)
    timestamps: list[datetime] = []
    for index, reading in enumerate(readings):
        if reading.ts is not None:
            timestamps.append(_clamp_device_timestamp(reading.ts, server_now))
        else:
            timestamps.append(server_now + timedelta(microseconds=index))
    return timestamps


async def ingest_readings(
    session: AsyncSession,
    sensor: Sensor,
    readings: list[ReadingIn],
) -> int:
    if not readings:
        return 0

    received_at = datetime.now(UTC)
    timestamps = _resolve_timestamps(readings)
    rows = [
        (timestamps[index], sensor.id, reading.current_a, reading.power_w)
        for index, reading in enumerate(readings)
    ]

    accepted = await reading_repository.bulk_insert_readings(session, rows)
    await sensor_repository.update_last_seen(session, sensor.id, received_at)
    await handle_telemetry_activity(session, sensor, readings, received_at)
    await session.commit()
    return accepted
