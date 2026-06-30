from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.sensor import BucketParam, ReadingPoint

MAX_POINTS = 2000

_AGGREGATE_TABLES: dict[BucketParam, str] = {
    BucketParam.minute: "readings_minute",
    BucketParam.hour: "readings_hour",
    BucketParam.day: "readings_day",
}


def auto_select_bucket(from_dt: datetime, to_dt: datetime) -> BucketParam:
    duration_seconds = (to_dt - from_dt).total_seconds()
    if duration_seconds <= MAX_POINTS * 5:
        return BucketParam.raw
    if duration_seconds / 60 <= MAX_POINTS:
        return BucketParam.minute
    if duration_seconds / 3600 <= MAX_POINTS:
        return BucketParam.hour
    return BucketParam.day


async def fetch_readings(
    session: AsyncSession,
    sensor_id: int,
    from_dt: datetime,
    to_dt: datetime,
    bucket: BucketParam,
) -> list[ReadingPoint]:
    conn = await session.connection()
    raw_conn = await conn.get_raw_connection()
    driver = raw_conn.driver_connection

    if bucket == BucketParam.raw:
        rows = await driver.fetch(
            """
            SELECT time, current_a AS avg, current_a AS min, current_a AS max
            FROM readings
            WHERE sensor_id = $1 AND time >= $2 AND time <= $3
            ORDER BY time ASC
            LIMIT $4
            """,
            sensor_id,
            from_dt,
            to_dt,
            MAX_POINTS,
        )
    else:
        table = _AGGREGATE_TABLES[bucket]
        rows = await driver.fetch(
            f"""
            SELECT bucket AS time,
                   avg_current_a AS avg,
                   min_current_a AS min,
                   max_current_a AS max
            FROM {table}
            WHERE sensor_id = $1 AND bucket >= $2 AND bucket <= $3
            ORDER BY bucket ASC
            LIMIT $4
            """,
            sensor_id,
            from_dt,
            to_dt,
            MAX_POINTS,
        )

    return [
        ReadingPoint(
            time=row["time"],
            avg=float(row["avg"]),
            min=float(row["min"]),
            max=float(row["max"]),
        )
        for row in rows
    ]
