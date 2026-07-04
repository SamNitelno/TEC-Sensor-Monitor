from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_viewer
from app.db.session import get_db
from app.models.downtime_event import DowntimeType
from app.models.user import User
from app.schemas.downtime import (
    DowntimeEventsResponse,
    DowntimeSummaryResponse,
    DowntimeTypeParam,
)
from app.services import downtime_service

router = APIRouter(prefix="/downtime", tags=["downtime"])


@router.get("/events", response_model=DowntimeEventsResponse)
async def get_downtime_events(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_viewer)],
    from_dt: Annotated[datetime, Query(alias="from")],
    to_dt: Annotated[datetime, Query(alias="to")],
    sensor_id: Annotated[int | None, Query()] = None,
    site_id: Annotated[int | None, Query()] = None,
    workshop_id: Annotated[int | None, Query()] = None,
    event_type: Annotated[DowntimeTypeParam | None, Query(alias="type")] = None,
) -> DowntimeEventsResponse:
    return await downtime_service.list_events(
        db,
        from_dt=from_dt,
        to_dt=to_dt,
        sensor_id=sensor_id,
        site_id=site_id,
        workshop_id=workshop_id,
        event_type=DowntimeType(event_type.value) if event_type else None,
    )


@router.get("/summary", response_model=DowntimeSummaryResponse)
async def get_downtime_summary(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_viewer)],
    from_dt: Annotated[datetime, Query(alias="from")],
    to_dt: Annotated[datetime, Query(alias="to")],
    sensor_id: Annotated[int | None, Query()] = None,
    site_id: Annotated[int | None, Query()] = None,
    workshop_id: Annotated[int | None, Query()] = None,
) -> DowntimeSummaryResponse:
    return await downtime_service.summarize(
        db,
        from_dt=from_dt,
        to_dt=to_dt,
        sensor_id=sensor_id,
        site_id=site_id,
        workshop_id=workshop_id,
    )
