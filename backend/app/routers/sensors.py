from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_admin, require_viewer
from app.db.session import get_db
from app.models.user import User
from app.repositories import sensor_repository
from app.schemas.notification_prefs import BulkNotificationsRequest, BulkNotificationsResponse
from app.schemas.sensor import (
    BucketParam,
    GroupedReadingsResponse,
    ProvisioningTokenResponse,
    RotateTokenResponse,
    ReadingsResponse,
    SensorAuditInfo,
    SensorCreate,
    SensorCreateResponse,
    SensorDetail,
    DemoSeedResponse,
    SensorListItem,
    SensorUpdate,
)
from app.services.sensor_status import effective_status
from app.services import demo_readings_service, readings_service, sensor_service

router = APIRouter(prefix="/sensors", tags=["sensors"])


def _to_list_item(sensor) -> SensorListItem:
    sensor_status = effective_status(sensor)
    return SensorListItem(
        id=sensor.id,
        name=sensor.name,
        device_id=sensor.device_id,
        site_id=sensor.site_id,
        status=sensor_status,
        last_seen=sensor.last_seen,
        color=sensor.color,
        idle_power_threshold_w=sensor.idle_power_threshold_w,
        idle_current_threshold_a=sensor.idle_current_threshold_a,
        idle_duration_seconds=sensor.idle_duration_seconds,
        notifications_enabled=sensor.notifications_enabled,
        created_at=sensor.created_at,
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


@router.post("/notifications/bulk", response_model=BulkNotificationsResponse)
async def bulk_notifications(
    payload: BulkNotificationsRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> BulkNotificationsResponse:
    updated = await sensor_service.set_all_notifications_enabled(
        db, enabled=payload.enabled
    )
    return BulkNotificationsResponse(updated=updated)


@router.post("/seed-demo-readings", response_model=DemoSeedResponse)
async def seed_demo_readings(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> DemoSeedResponse:
    result = await demo_readings_service.seed_demo_sensor_readings(db)
    return DemoSeedResponse(**result)


@router.get("/{sensor_id}", response_model=SensorDetail)
async def get_sensor(
    sensor_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_viewer)],
) -> SensorDetail:
    return await sensor_service.get_sensor_detail(db, sensor_id)


@router.get("/{sensor_id}/audit", response_model=SensorAuditInfo)
async def get_sensor_audit(
    sensor_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> SensorAuditInfo:
    return await sensor_service.get_sensor_audit(db, sensor_id)


@router.get("/{sensor_id}/provisioning-token", response_model=ProvisioningTokenResponse)
async def get_provisioning_token(
    sensor_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> ProvisioningTokenResponse:
    return await sensor_service.get_provisioning_token(db, sensor_id)


@router.post("/{sensor_id}/rotate-token", response_model=RotateTokenResponse)
async def rotate_sensor_token(
    sensor_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> RotateTokenResponse:
    return await sensor_service.rotate_device_token(db, sensor_id)


@router.post("", response_model=SensorCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_sensor(
    payload: SensorCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    actor: Annotated[User, Depends(require_admin)],
) -> SensorCreateResponse:
    return await sensor_service.create_sensor(db, payload, created_by=actor)


@router.patch("/{sensor_id}", response_model=SensorDetail)
async def update_sensor(
    sensor_id: int,
    payload: SensorUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    actor: Annotated[User, Depends(require_admin)],
) -> SensorDetail:
    return await sensor_service.update_sensor(db, sensor_id, payload, actor=actor)


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
