from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sensor import Sensor
from app.repositories import reading_repository, sensor_repository
from app.schemas.ingest import ReadingIn


def _resolve_timestamps(readings: list[ReadingIn]) -> list[datetime]:
    now = datetime.now(UTC)
    timestamps: list[datetime] = []
    for index, reading in enumerate(readings):
        if reading.ts is not None:
            ts = reading.ts
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=UTC)
            else:
                ts = ts.astimezone(UTC)
            timestamps.append(ts)
        else:
            timestamps.append(now + timedelta(microseconds=index))
    return timestamps


async def ingest_readings(
    session: AsyncSession,
    sensor: Sensor,
    readings: list[ReadingIn],
) -> int:
    if not readings:
        return 0

    timestamps = _resolve_timestamps(readings)
    rows = [
        (timestamps[index], sensor.id, reading.current_a)
        for index, reading in enumerate(readings)
    ]

    accepted = await reading_repository.bulk_insert_readings(session, rows)
    await sensor_repository.update_last_seen(session, sensor.id, max(timestamps))
    await session.commit()
    return accepted
