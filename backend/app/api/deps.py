from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.sensor import Sensor
from app.repositories import sensor_repository


async def get_sensor_by_device_token(
    db: Annotated[AsyncSession, Depends(get_db)],
    x_device_token: Annotated[str | None, Header()] = None,
) -> Sensor:
    if not x_device_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid device token",
        )
    sensor = await sensor_repository.get_by_api_token(db, x_device_token)
    if sensor is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid device token",
        )
    return sensor
