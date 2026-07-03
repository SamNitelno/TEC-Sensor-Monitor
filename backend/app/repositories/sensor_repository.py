from datetime import datetime

from sqlalchemy import select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sensor import Sensor, SensorStatus
from app.models.site import Site


async def list_all(
    session: AsyncSession,
    *,
    site_id: int | None = None,
    workshop_id: int | None = None,
) -> list[Sensor]:
    query = select(Sensor).order_by(Sensor.id)
    if site_id is not None:
        query = query.where(Sensor.site_id == site_id)
    elif workshop_id is not None:
        query = query.join(Site, Sensor.site_id == Site.id).where(
            Site.workshop_id == workshop_id
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
    site_id: int | None,
) -> Sensor:
    sensor = Sensor(
        name=name,
        device_id=device_id,
        api_token=api_token,
        site_id=site_id,
    )
    session.add(sensor)
    await session.flush()
    return sensor


async def update(
    session: AsyncSession,
    sensor: Sensor,
    *,
    name: str | None = None,
    site_id: int | None = None,
    clear_site: bool = False,
) -> Sensor:
    if name is not None:
        sensor.name = name
    if clear_site:
        sensor.site_id = None
    elif site_id is not None:
        sensor.site_id = site_id
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


async def mark_stale_offline(
    session: AsyncSession,
    *,
    older_than: datetime,
) -> int:
    result = await session.execute(
        sa_update(Sensor)
        .where(Sensor.status == SensorStatus.online)
        .where(Sensor.last_seen.is_not(None))
        .where(Sensor.last_seen < older_than)
        .values(status=SensorStatus.offline)
    )
    return result.rowcount or 0
