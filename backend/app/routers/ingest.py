from typing import Annotated

import logging

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_sensor_by_device_token
from app.db.session import get_db
from app.models.sensor import Sensor
from app.schemas.ingest import IngestPayload, IngestResponse
from app.services import ingest_service

logger = logging.getLogger(__name__)

router = APIRouter(tags=["ingest"])


@router.post(
    "/ingest",
    status_code=status.HTTP_202_ACCEPTED,
    response_model=IngestResponse,
)
async def ingest(
    payload: IngestPayload,
    sensor: Annotated[Sensor, Depends(get_sensor_by_device_token)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> IngestResponse:
    accepted = await ingest_service.ingest_readings(db, sensor, payload)
    logger.info("Ingest sensor_id=%s accepted=%s", sensor.id, accepted)
    return IngestResponse(accepted=accepted)
