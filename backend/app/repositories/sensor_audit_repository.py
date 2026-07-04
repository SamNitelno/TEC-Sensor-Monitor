from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.sensor import Sensor
from app.models.sensor_placement_history import SensorPlacementHistory
from app.models.site import Site


async def record_placement(
    session: AsyncSession,
    *,
    sensor_id: int,
    site_id: int | None,
    assigned_by_user_id: int | None,
) -> SensorPlacementHistory:
    entry = SensorPlacementHistory(
        sensor_id=sensor_id,
        site_id=site_id,
        assigned_by_user_id=assigned_by_user_id,
    )
    session.add(entry)
    await session.flush()
    return entry


async def list_for_sensor(session: AsyncSession, sensor_id: int) -> list[SensorPlacementHistory]:
    result = await session.execute(
        select(SensorPlacementHistory)
        .where(SensorPlacementHistory.sensor_id == sensor_id)
        .order_by(SensorPlacementHistory.assigned_at.desc())
        .options(
            selectinload(SensorPlacementHistory.site).selectinload(Site.workshop),
            selectinload(SensorPlacementHistory.assigned_by),
        )
    )
    return list(result.scalars().all())


async def get_sensor_with_audit(session: AsyncSession, sensor_id: int) -> Sensor | None:
    result = await session.execute(
        select(Sensor)
        .where(Sensor.id == sensor_id)
        .options(
            selectinload(Sensor.created_by),
            selectinload(Sensor.site).selectinload(Site.workshop),
        )
    )
    return result.scalar_one_or_none()
