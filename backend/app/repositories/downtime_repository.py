from datetime import datetime

from sqlalchemy import select, update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.downtime_event import DowntimeEvent, DowntimeType
from app.models.sensor import Sensor, SensorStatus
from app.models.site import Site


async def get_open_event(
    session: AsyncSession,
    sensor_id: int,
    event_type: DowntimeType,
) -> DowntimeEvent | None:
    result = await session.execute(
        select(DowntimeEvent)
        .where(
            DowntimeEvent.sensor_id == sensor_id,
            DowntimeEvent.type == event_type,
            DowntimeEvent.ended_at.is_(None),
        )
        .order_by(DowntimeEvent.started_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def list_open_events(
    session: AsyncSession,
    sensor_id: int,
    event_type: DowntimeType,
) -> list[DowntimeEvent]:
    result = await session.execute(
        select(DowntimeEvent)
        .where(
            DowntimeEvent.sensor_id == sensor_id,
            DowntimeEvent.type == event_type,
            DowntimeEvent.ended_at.is_(None),
        )
        .order_by(DowntimeEvent.started_at.asc())
    )
    return list(result.scalars().all())


async def create_event(
    session: AsyncSession,
    *,
    sensor_id: int,
    event_type: DowntimeType,
    started_at: datetime,
) -> DowntimeEvent:
    event = DowntimeEvent(
        sensor_id=sensor_id,
        type=event_type,
        started_at=started_at,
    )
    session.add(event)
    await session.flush()
    return event


async def close_event(
    session: AsyncSession,
    event: DowntimeEvent,
    ended_at: datetime,
) -> None:
    event.ended_at = ended_at
    await session.flush()


async def list_events_in_range(
    session: AsyncSession,
    *,
    from_dt: datetime,
    to_dt: datetime,
    sensor_ids: list[int] | None = None,
    site_id: int | None = None,
    workshop_id: int | None = None,
    event_type: DowntimeType | None = None,
) -> list[DowntimeEvent]:
    query = (
        select(DowntimeEvent)
        .options(
            selectinload(DowntimeEvent.sensor)
            .selectinload(Sensor.site)
            .selectinload(Site.workshop)
        )
        .join(Sensor, DowntimeEvent.sensor_id == Sensor.id)
        .where(DowntimeEvent.started_at < to_dt)
        .where(
            (DowntimeEvent.ended_at.is_(None)) | (DowntimeEvent.ended_at > from_dt)
        )
    )
    if sensor_ids:
        query = query.where(DowntimeEvent.sensor_id.in_(sensor_ids))
    if site_id is not None:
        query = query.where(Sensor.site_id == site_id)
    if workshop_id is not None:
        query = query.join(Site, Sensor.site_id == Site.id).where(
            Site.workshop_id == workshop_id
        )
    if event_type is not None:
        query = query.where(DowntimeEvent.type == event_type)
    query = query.order_by(DowntimeEvent.started_at.desc())
    result = await session.execute(query)
    return list(result.scalars().unique().all())


async def list_sensors_for_scope(
    session: AsyncSession,
    *,
    sensor_ids: list[int] | None = None,
    site_id: int | None = None,
    workshop_id: int | None = None,
) -> list[Sensor]:
    query = select(Sensor).options(
        selectinload(Sensor.site).selectinload(Site.workshop)
    )
    if sensor_ids:
        query = query.where(Sensor.id.in_(sensor_ids))
    if site_id is not None:
        query = query.where(Sensor.site_id == site_id)
    if workshop_id is not None:
        query = query.join(Site, Sensor.site_id == Site.id).where(
            Site.workshop_id == workshop_id
        )
    result = await session.execute(query.order_by(Sensor.id))
    return list(result.scalars().all())
