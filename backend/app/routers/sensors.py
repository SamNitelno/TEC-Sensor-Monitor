from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_admin, require_viewer
from app.db.session import get_db
from app.models.user import User
from app.repositories import sensor_repository
from app.schemas.sensor import (
    BucketParam,
    GroupedReadingsResponse,
    ProvisioningTokenResponse,
    ReadingsResponse,
    SensorCreate,
    SensorCreateResponse,
    SensorDetail,
    SensorListItem,
    SensorUpdate,
)
from app.services import readings_service, sensor_service

router = APIRouter(prefix="/sensors", tags=["sensors"])


def _to_list_item(sensor) -> SensorListItem:
    return SensorListItem(
        id=sensor.id,
        name=sensor.name,
        device_id=sensor.device_id,
        workshop_id=sensor.workshop_id,
        status=sensor.status,
        last_seen=sensor.last_seen,
    )


@router.get("", response_model=list[SensorListItem])
async def list_sensors(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_viewer)],
    site_id: Annotated[int | None, Query()] = None,
    workshop_id: Annotated[int | None, Query()] = None,
) -> list[SensorListItem]:
    sensors = await sensor_repository.list_all(
        db,
        site_id=site_id,
        workshop_id=workshop_id,
    )
    return [_to_list_item(sensor) for sensor in sensors]


@router.get("/{sensor_id}", response_model=SensorDetail)
async def get_sensor(
    sensor_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_viewer)],
) -> SensorDetail:
    return await sensor_service.get_sensor_detail(db, sensor_id)


@router.get("/{sensor_id}/provisioning-token", response_model=ProvisioningTokenResponse)
async def get_provisioning_token(
    sensor_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> ProvisioningTokenResponse:
    return await sensor_service.get_provisioning_token(db, sensor_id)


@router.post("", response_model=SensorCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_sensor(
    payload: SensorCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> SensorCreateResponse:
    return await sensor_service.create_sensor(db, payload)


@router.patch("/{sensor_id}", response_model=SensorDetail)
async def update_sensor(
    sensor_id: int,
    payload: SensorUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> SensorDetail:
    return await sensor_service.update_sensor(db, sensor_id, payload)


@router.delete("/{sensor_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_sensor(
    sensor_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> Response:
    await sensor_service.delete_sensor(db, sensor_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{sensor_id}/readings", response_model=ReadingsResponse)
async def get_sensor_readings(
    sensor_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_viewer)],
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
