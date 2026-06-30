from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories import sensor_repository
from app.schemas.sensor import BucketParam, ReadingsResponse, SensorListItem
from app.services import readings_service

router = APIRouter(prefix="/sensors", tags=["sensors"])


@router.get("", response_model=list[SensorListItem])
async def list_sensors(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[SensorListItem]:
    sensors = await sensor_repository.list_all(db)
    return [
        SensorListItem(id=sensor.id, name=sensor.name, status=sensor.status)
        for sensor in sensors
    ]


@router.get("/{sensor_id}/readings", response_model=ReadingsResponse)
async def get_sensor_readings(
    sensor_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    from_dt: Annotated[datetime, Query(alias="from")],
    to_dt: Annotated[datetime, Query(alias="to")],
    bucket: Annotated[BucketParam | None, Query()] = None,
) -> ReadingsResponse:
    return await readings_service.get_sensor_readings(
        db,
        sensor_id,
        from_dt,
        to_dt,
        bucket,
    )
