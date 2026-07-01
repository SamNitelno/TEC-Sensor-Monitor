from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import readings_query_repository, sensor_repository
from app.schemas.sensor import BucketParam, GroupedReadingsResponse, ReadingsResponse, SensorSeries


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


async def get_grouped_readings(
    session: AsyncSession,
    sensor_ids: list[int],
    from_dt: datetime,
    to_dt: datetime,
    bucket: BucketParam | None,
    *,
    site_id: int | None = None,
    workshop_id: int | None = None,
) -> GroupedReadingsResponse:
    if from_dt > to_dt:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="'from' must be before 'to'",
        )

    if sensor_ids:
        sensors = await sensor_repository.get_many_by_ids(session, sensor_ids)
    else:
        sensors = await sensor_repository.list_all(
            session,
            site_id=site_id,
            workshop_id=workshop_id,
        )

    if not sensors:
        return GroupedReadingsResponse(series=[])

    resolved_bucket = bucket or readings_query_repository.auto_select_bucket(from_dt, to_dt)
    series: list[SensorSeries] = []
    for sensor in sensors:
        points = await readings_query_repository.fetch_readings(
            session,
            sensor.id,
            from_dt,
            to_dt,
            resolved_bucket,
        )
        series.append(
            SensorSeries(
                sensor_id=sensor.id,
                sensor_name=sensor.name,
                bucket=resolved_bucket,
                points=points,
            )
        )
    return GroupedReadingsResponse(series=series)
