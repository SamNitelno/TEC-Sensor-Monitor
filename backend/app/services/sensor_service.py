import secrets

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.sensor import Sensor
from app.models.user import User
from app.repositories import sensor_audit_repository, sensor_repository, site_repository
from app.services.sensor_status import effective_status
from app.schemas.sensor import (
    IntegrationSnippet,
    ProvisioningTokenResponse,
    SensorAuditInfo,
    SensorCreate,
    SensorCreateResponse,
    SensorDetail,
    SensorPlacementRecord,
    SensorUpdate,
)


def _to_detail(sensor: Sensor) -> SensorDetail:
    return SensorDetail(
        id=sensor.id,
        name=sensor.name,
        device_id=sensor.device_id,
        site_id=sensor.site_id,
        status=effective_status(sensor),
        last_seen=sensor.last_seen,
        created_at=sensor.created_at,
        color=sensor.color,
        idle_power_threshold_w=sensor.idle_power_threshold_w,
        idle_current_threshold_a=sensor.idle_current_threshold_a,
        idle_duration_seconds=sensor.idle_duration_seconds,
        notifications_enabled=sensor.notifications_enabled,
    )


def build_integration_snippet(api_token: str) -> IntegrationSnippet:
    base = settings.api_public_base_url.rstrip("/")
    url = f"{base}/api/v1/ingest"
    headers = {
        "Content-Type": "application/json",
        "X-Device-Token": api_token,
    }
    body_example = {"current_a": 4.25, "power_w": 980.0}
    curl = (
        f'curl -X POST "{url}" \\\n'
        f'  -H "Content-Type: application/json" \\\n'
        f'  -H "X-Device-Token: {api_token}" \\\n'
        f"  -d '{{\"current_a\": 4.25, \"power_w\": 980.0}}'"
    )
    return IntegrationSnippet(
        url=url,
        headers=headers,
        body_schema={
            "current_a": "float A RMS (required)",
            "power_w": "float W (optional)",
            "ts": "ISO8601 string (optional)",
        },
        body_example=body_example,
        curl=curl,
    )


async def create_sensor(
    session: AsyncSession,
    payload: SensorCreate,
    *,
    created_by: User | None = None,
) -> SensorCreateResponse:
    existing = await sensor_repository.get_by_device_id(session, payload.device_id)
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="device_id already exists",
        )
    if payload.site_id is not None:
        site = await site_repository.get_by_id(session, payload.site_id)
        if site is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")

    api_token = secrets.token_urlsafe(32)
    sensor = await sensor_repository.create(
        session,
        name=payload.name,
        device_id=payload.device_id,
        api_token=api_token,
        site_id=payload.site_id,
        color=payload.color,
        created_by_user_id=created_by.id if created_by else None,
    )
    await sensor_audit_repository.record_placement(
        session,
        sensor_id=sensor.id,
        site_id=payload.site_id,
        assigned_by_user_id=created_by.id if created_by else None,
    )
    await session.commit()
    await session.refresh(sensor)
    return SensorCreateResponse(
        sensor=_to_detail(sensor),
        api_token=api_token,
        integration=build_integration_snippet(api_token),
    )


async def update_sensor(
    session: AsyncSession,
    sensor_id: int,
    payload: SensorUpdate,
    *,
    actor: User | None = None,
) -> SensorDetail:
    sensor = await sensor_repository.get_by_id(session, sensor_id)
    if sensor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor not found")

    updates = payload.model_dump(exclude_unset=True)
    old_site_id = sensor.site_id

    if "site_id" in updates and updates["site_id"] is not None:
        site = await site_repository.get_by_id(session, updates["site_id"])
        if site is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")

    clear_site = "site_id" in updates and updates["site_id"] is None
    new_site_id = None if clear_site else updates.get("site_id", sensor.site_id)

    await sensor_repository.update(
        session,
        sensor,
        name=updates.get("name"),
        site_id=updates.get("site_id"),
        clear_site=clear_site,
        color=updates.get("color"),
        clear_color=updates.get("clear_color", False),
        idle_power_threshold_w=updates.get("idle_power_threshold_w"),
        clear_idle_power_threshold=updates.get("clear_idle_power_threshold", False),
        idle_current_threshold_a=updates.get("idle_current_threshold_a"),
        clear_idle_current_threshold=updates.get(
            "clear_idle_current_threshold", False
        ),
        idle_duration_seconds=updates.get("idle_duration_seconds"),
        clear_idle_duration=updates.get("clear_idle_duration", False),
        notifications_enabled=updates.get("notifications_enabled"),
    )

    if "site_id" in updates and new_site_id != old_site_id:
        await sensor_audit_repository.record_placement(
            session,
            sensor_id=sensor.id,
            site_id=new_site_id,
            assigned_by_user_id=actor.id if actor else None,
        )

    await session.commit()
    await session.refresh(sensor)
    return _to_detail(sensor)


async def delete_sensor(session: AsyncSession, sensor_id: int) -> None:
    sensor = await sensor_repository.get_by_id(session, sensor_id)
    if sensor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor not found")
    await sensor_repository.delete(session, sensor)
    await session.commit()


async def get_sensor_detail(session: AsyncSession, sensor_id: int) -> SensorDetail:
    sensor = await sensor_repository.get_by_id(session, sensor_id)
    if sensor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor not found")
    return _to_detail(sensor)


async def get_sensor_audit(session: AsyncSession, sensor_id: int) -> SensorAuditInfo:
    sensor = await sensor_audit_repository.get_sensor_with_audit(session, sensor_id)
    if sensor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor not found")

    history = await sensor_audit_repository.list_for_sensor(session, sensor_id)
    records = []
    for entry in history:
        site = entry.site
        records.append(
            SensorPlacementRecord(
                site_id=entry.site_id,
                site_name=site.name if site else None,
                workshop_id=site.workshop_id if site else None,
                workshop_name=site.workshop.name if site and site.workshop else None,
                assigned_at=entry.assigned_at,
                assigned_by_login=entry.assigned_by.login if entry.assigned_by else None,
            )
        )

    site = sensor.site
    return SensorAuditInfo(
        id=sensor.id,
        name=sensor.name,
        device_id=sensor.device_id,
        created_at=sensor.created_at,
        created_by_login=sensor.created_by.login if sensor.created_by else None,
        current_site_id=sensor.site_id,
        current_site_name=site.name if site else None,
        current_workshop_id=site.workshop_id if site else None,
        current_workshop_name=site.workshop.name if site and site.workshop else None,
        color=sensor.color,
        placement_history=records,
    )


async def set_all_notifications_enabled(
    session: AsyncSession,
    *,
    enabled: bool,
) -> int:
    updated = await sensor_repository.set_notifications_enabled_all(
        session, enabled=enabled
    )
    await session.commit()
    return updated


async def get_provisioning_token(
    session: AsyncSession,
    sensor_id: int,
) -> ProvisioningTokenResponse:
    sensor = await sensor_repository.get_by_id(session, sensor_id)
    if sensor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor not found")
    base = settings.api_public_base_url.rstrip("/")
    return ProvisioningTokenResponse(
        api_token=sensor.api_token,
        ingest_url=f"{base}/api/v1/ingest",
    )
