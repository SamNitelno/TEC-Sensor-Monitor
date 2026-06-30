from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sensor import Sensor, SensorStatus


async def get_by_api_token(session: AsyncSession, api_token: str) -> Sensor | None:
    result = await session.execute(select(Sensor).where(Sensor.api_token == api_token))
    return result.scalar_one_or_none()


async def update_last_seen(
    session: AsyncSession,
    sensor_id: int,
    last_seen: datetime,
) -> None:
    await session.execute(
        update(Sensor)
        .where(Sensor.id == sensor_id)
        .values(last_seen=last_seen, status=SensorStatus.online)
    )
