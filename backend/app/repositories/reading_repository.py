from datetime import datetime

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.reading import Reading


async def bulk_insert_readings(
    session: AsyncSession,
    rows: list[tuple[datetime, int, float, float | None]],
) -> int:
    """Insert readings in one round-trip via asyncpg executemany."""
    if not rows:
        return 0

    conn = await session.connection()
    raw_conn = await conn.get_raw_connection()
    await raw_conn.driver_connection.executemany(
        """
        INSERT INTO readings (time, sensor_id, current_a, power_w)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (time, sensor_id) DO UPDATE
        SET current_a = EXCLUDED.current_a,
            power_w = EXCLUDED.power_w
        """,
        rows,
    )
    return len(rows)


async def delete_for_sensors(session: AsyncSession, sensor_ids: list[int]) -> None:
    if not sensor_ids:
        return

    await session.execute(delete(Reading).where(Reading.sensor_id.in_(sensor_ids)))


async def get_recent_readings(
    session: AsyncSession,
    sensor_id: int,
    *,
    limit: int = 10,
) -> list[Reading]:
    result = await session.execute(
        select(Reading)
        .where(Reading.sensor_id == sensor_id)
        .order_by(Reading.time.desc())
        .limit(limit)
    )
    rows = list(result.scalars().all())
    rows.reverse()
    return rows
