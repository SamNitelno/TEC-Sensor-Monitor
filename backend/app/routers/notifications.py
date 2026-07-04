from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.notification import NotificationAckResponse, NotificationCountResponse, NotificationItem
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationItem])
async def list_notifications(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[NotificationItem]:
    return await notification_service.list_unread(db, user)


@router.get("/unread-count", response_model=NotificationCountResponse)
async def unread_count(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> NotificationCountResponse:
    return await notification_service.unread_count(db, user)


@router.post("/ack-all")
async def acknowledge_all(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> dict[str, int]:
    count = await notification_service.acknowledge_all(db, user)
    return {"acknowledged": count}


@router.post("/{notification_id}/ack", response_model=NotificationAckResponse)
async def acknowledge_notification(
    notification_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> NotificationAckResponse:
    return await notification_service.acknowledge(db, user, notification_id)
