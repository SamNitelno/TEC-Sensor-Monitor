from datetime import datetime

from sqlalchemy import select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sensor import Sensor, SensorStatus
from app.models.workshop import Workshop


async def list_all(
    session: AsyncSession,
    *,
    site_id: int | None = None,
    workshop_id: int | None = None,
) -> list[Sensor]:
    query = select(Sensor).order_by(Sensor.id)
    if workshop_id is not None:
        query = query.where(Sensor.workshop_id == workshop_id)
    elif site_id is not None:
        query = query.join(Workshop, Sensor.workshop_id == Workshop.id).where(
            Workshop.site_id == site_id
        )
    result = await session.execute(query)
    return list(result.scalars().all())


async def get_by_id(session: AsyncSession, sensor_id: int) -> Sensor | None:
    result = await session.execute(select(Sensor).where(Sensor.id == sensor_id))
    return result.scalar_one_or_none()


async def get_by_device_id(session: AsyncSession, device_id: str) -> Sensor | None:
    result = await session.execute(select(Sensor).where(Sensor.device_id == device_id))
    return result.scalar_one_or_none()


async def get_by_api_token(session: AsyncSession, api_token: str) -> Sensor | None:
    result = await session.execute(select(Sensor).where(Sensor.api_token == api_token))
    return result.scalar_one_or_none()


async def get_many_by_ids(session: AsyncSession, sensor_ids: list[int]) -> list[Sensor]:
    if not sensor_ids:
        return []
    result = await session.execute(select(Sensor).where(Sensor.id.in_(sensor_ids)))
    return list(result.scalars().all())


async def create(
    session: AsyncSession,
    *,
    name: str,
    device_id: str,
    api_token: str,
    workshop_id: int | None,
) -> Sensor:
    sensor = Sensor(
        name=name,
        device_id=device_id,
        api_token=api_token,
        workshop_id=workshop_id,
    )
    session.add(sensor)
    await session.flush()
    return sensor


async def update(
    session: AsyncSession,
    sensor: Sensor,
    *,
    name: str | None = None,
    workshop_id: int | None = None,
    clear_workshop: bool = False,
) -> Sensor:
    if name is not None:
        sensor.name = name
    if clear_workshop:
        sensor.workshop_id = None
    elif workshop_id is not None:
        sensor.workshop_id = workshop_id
    await session.flush()
    return sensor


async def delete(session: AsyncSession, sensor: Sensor) -> None:
    await session.delete(sensor)


async def update_last_seen(
    session: AsyncSession,
    sensor_id: int,
    last_seen: datetime,
) -> None:
    await session.execute(
        sa_update(Sensor)
        .where(Sensor.id == sensor_id)
        .values(last_seen=last_seen, status=SensorStatus.online)
    )
