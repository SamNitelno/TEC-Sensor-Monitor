from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_admin
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    AdminPasswordResetRequest,
    AdminPasswordResetResponse,
    DemoteResponse,
    PromoteResponse,
    UserListItem,
)
from app.services import password_reset_service, user_service

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=list[UserListItem])
async def list_users(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> list[UserListItem]:
    return await user_service.list_users(db)


@router.post("/{user_id}/reset-password", response_model=AdminPasswordResetResponse)
async def admin_reset_password(
    user_id: int,
    payload: AdminPasswordResetRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    actor: Annotated[User, Depends(require_admin)],
) -> AdminPasswordResetResponse:
    await password_reset_service.admin_reset_password(
        db, actor=actor, target_user_id=user_id, payload=payload
    )
    return AdminPasswordResetResponse()


@router.post("/{user_id}/promote", response_model=PromoteResponse)
async def promote_user(
    user_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    actor: Annotated[User, Depends(require_admin)],
) -> PromoteResponse:
    return await user_service.promote_user(db, actor, user_id)


@router.post("/{user_id}/demote", response_model=DemoteResponse)
async def demote_user(
    user_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    actor: Annotated[User, Depends(require_admin)],
) -> DemoteResponse:
    return await user_service.demote_user(db, actor, user_id)
