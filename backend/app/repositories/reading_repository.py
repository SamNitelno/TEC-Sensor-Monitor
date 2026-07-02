from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession


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
        "INSERT INTO readings (time, sensor_id, current_a, power_w) VALUES ($1, $2, $3, $4)",
        rows,
    )
    return len(rows)
