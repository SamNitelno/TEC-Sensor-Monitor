from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import readings_query_repository, sensor_repository
from app.schemas.sensor import BucketParam, ReadingsResponse


async def get_sensor_readings(
    session: AsyncSession,
    sensor_id: int,
    from_dt: datetime,
    to_dt: datetime,
    bucket: BucketParam | None,
) -> ReadingsResponse:
    if from_dt > to_dt:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="'from' must be before 'to'",
        )

    sensor = await sensor_repository.get_by_id(session, sensor_id)
    if sensor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor not found")

    resolved_bucket = bucket or readings_query_repository.auto_select_bucket(from_dt, to_dt)
    points = await readings_query_repository.fetch_readings(
        session,
        sensor_id,
        from_dt,
        to_dt,
        resolved_bucket,
    )
    return ReadingsResponse(bucket=resolved_bucket, points=points)
