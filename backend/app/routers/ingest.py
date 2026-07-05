from typing import Annotated

import structlog
from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_sensor_by_device_token
from app.core.config import settings
from app.core.rate_limit import client_ip, limiter
from app.db.session import get_db
from app.models.sensor import Sensor
from app.schemas.ingest import IngestPayload, IngestResponse
from app.services import ingest_service

logger = structlog.get_logger(__name__)

router = APIRouter(tags=["ingest"])


@router.post(
    "/ingest",
    status_code=status.HTTP_202_ACCEPTED,
    response_model=IngestResponse,
)
@limiter.limit(settings.ingest_rate_limit, key_func=client_ip)
async def ingest(
    request: Request,
    payload: IngestPayload,
    sensor: Annotated[Sensor, Depends(get_sensor_by_device_token)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> IngestResponse:
    accepted = await ingest_service.ingest_readings(db, sensor, payload)
    logger.info("ingest_accepted", sensor_id=sensor.id, accepted=accepted)
    return IngestResponse(accepted=accepted)
