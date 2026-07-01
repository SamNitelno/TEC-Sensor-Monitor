import secrets

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.sensor import Sensor
from app.repositories import sensor_repository, site_repository, workshop_repository
from app.schemas.sensor import (
    IntegrationSnippet,
    ProvisioningTokenResponse,
    SensorCreate,
    SensorCreateResponse,
    SensorDetail,
    SensorUpdate,
)


def _to_detail(sensor: Sensor) -> SensorDetail:
    return SensorDetail(
        id=sensor.id,
        name=sensor.name,
        device_id=sensor.device_id,
        workshop_id=sensor.workshop_id,
        status=sensor.status,
        last_seen=sensor.last_seen,
        created_at=sensor.created_at,
    )


def build_integration_snippet(api_token: str) -> IntegrationSnippet:
    base = settings.api_public_base_url.rstrip("/")
    url = f"{base}/api/v1/ingest"
    headers = {
        "Content-Type": "application/json",
        "X-Device-Token": api_token,
    }
    body_example = {"current_a": 4.25}
    curl = (
        f'curl -X POST "{url}" \\\n'
        f'  -H "Content-Type: application/json" \\\n'
        f'  -H "X-Device-Token: {api_token}" \\\n'
        f"  -d '{{\"current_a\": 4.25}}'"
    )
    return IntegrationSnippet(
        url=url,
        headers=headers,
        body_schema={"current_a": "float (required)", "ts": "ISO8601 string (optional)"},
        body_example=body_example,
        curl=curl,
    )


async def create_sensor(session: AsyncSession, payload: SensorCreate) -> SensorCreateResponse:
    existing = await sensor_repository.get_by_device_id(session, payload.device_id)
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="device_id already exists",
        )
    if payload.workshop_id is not None:
        workshop = await workshop_repository.get_by_id(session, payload.workshop_id)
        if workshop is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workshop not found")

    api_token = secrets.token_urlsafe(32)
    sensor = await sensor_repository.create(
        session,
        name=payload.name,
        device_id=payload.device_id,
        api_token=api_token,
        workshop_id=payload.workshop_id,
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
) -> SensorDetail:
    sensor = await sensor_repository.get_by_id(session, sensor_id)
    if sensor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor not found")

    updates = payload.model_dump(exclude_unset=True)
    if "workshop_id" in updates and updates["workshop_id"] is not None:
        workshop = await workshop_repository.get_by_id(session, updates["workshop_id"])
        if workshop is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workshop not found")

    clear_workshop = "workshop_id" in updates and updates["workshop_id"] is None
    await sensor_repository.update(
        session,
        sensor,
        name=updates.get("name"),
        workshop_id=updates.get("workshop_id"),
        clear_workshop=clear_workshop,
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
