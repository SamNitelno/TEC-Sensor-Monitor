import logging
import math
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sensor import Sensor
from app.repositories import reading_repository, sensor_repository

logger = logging.getLogger(__name__)

DEMO_SENSOR_NAMES = frozenset(
    {
        "Демо датчик 1",
        "Демо датчик 2",
        "Демо датчик 3",
        "Smoke Sensor",
    }
)


async def _refresh_continuous_aggregates(session: AsyncSession) -> None:
    try:
        conn = await session.connection()
        raw_conn = await conn.get_raw_connection()
        driver = raw_conn.driver_connection
        for view in ("readings_minute", "readings_hour", "readings_day"):
            await driver.execute(f"CALL refresh_continuous_aggregate('{view}', NULL, NULL)")
    except Exception:
        logger.warning("Continuous aggregate refresh failed", exc_info=True)


async def seed_demo_sensor_readings(session: AsyncSession) -> dict[str, int]:
    """Synthetic readings for demo sensors (not live ESP hardware)."""
    result = await session.execute(
        select(Sensor).where(Sensor.name.in_(DEMO_SENSOR_NAMES))
    )
    sensors = list(result.scalars().all())
    if not sensors:
        return {"sensors": 0, "points": 0, "sensor_names": []}

    sensor_ids = [sensor.id for sensor in sensors]
    await reading_repository.delete_for_sensors(session, sensor_ids)
    await session.flush()

    now = datetime.now(UTC)
    total_points = 0
    seeded_names: list[str] = []

    for index, sensor in enumerate(sorted(sensors, key=lambda s: s.name)):
        rows: list[tuple[datetime, int, float, float | None]] = []
        base = 3.5 + index * 1.8

        # Last 24 h, every 5 s — matches ESP telemetry cadence.
        steps = 24 * 60 * 12
        for step in range(steps):
            ts = now - timedelta(seconds=(steps - 1 - step) * 5)
            t = step / 12.0
            wave = math.sin(t / 10.0 + index) * 1.5
            pulse = 0.3 * math.sin(t / 2.5)
            current = max(0.15, base + wave + pulse + (step % 120) * 0.002)
            power = round(current * 230, 1)
            rows.append((ts, sensor.id, round(current, 3), power))

            if len(rows) >= 4000:
                total_points += await reading_repository.bulk_insert_readings(session, rows)
                rows = []

        if rows:
            total_points += await reading_repository.bulk_insert_readings(session, rows)

        await sensor_repository.update_last_seen(session, sensor.id, now)
        seeded_names.append(sensor.name)

    await session.commit()
    await _refresh_continuous_aggregates(session)

    return {
        "sensors": len(sensors),
        "points": total_points,
        "sensor_names": seeded_names,
    }
