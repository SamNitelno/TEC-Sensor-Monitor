from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_viewer
from app.db.session import get_db
from app.models.user import User
from app.schemas.sensor import BucketParam, GroupedReadingsResponse
from app.services import readings_service

router = APIRouter(prefix="/readings", tags=["readings"])


@router.get("", response_model=GroupedReadingsResponse)
async def get_grouped_readings(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_viewer)],
    from_dt: Annotated[datetime, Query(alias="from")],
    to_dt: Annotated[datetime, Query(alias="to")],
    sensor_ids: Annotated[list[int] | None, Query()] = None,
    site_id: Annotated[int | None, Query()] = None,
    workshop_id: Annotated[int | None, Query()] = None,
    bucket: Annotated[BucketParam | None, Query()] = None,
) -> GroupedReadingsResponse:
    return await readings_service.get_grouped_readings(
        db,
        sensor_ids or [],
        from_dt,
        to_dt,
        bucket,
        site_id=site_id,
        workshop_id=workshop_id,
    )
