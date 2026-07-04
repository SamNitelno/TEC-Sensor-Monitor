from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.repositories import user_repository
from app.services import notification_service
from app.schemas.auth import DemoteResponse, PromoteResponse, UserListItem
from app.services import auth_service
from app.services.user_hierarchy_service import can_demote_admin


def _to_list_item(user: User) -> UserListItem:
    return UserListItem(
        id=user.id,
        login=user.login,
        role=user.role,
        email=user.email,
        phone=user.phone,
        promoted_by_user_id=user.promoted_by_user_id,
        created_at=user.created_at,
    )


async def promote_user(
    session: AsyncSession,
    actor: User,
    target_user_id: int,
) -> PromoteResponse:
    if actor.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only")

    target = await user_repository.get_by_id(session, target_user_id)
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if target.role == UserRole.admin:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already admin")

    await user_repository.set_role(
        session,
        target,
        role=UserRole.admin,
        promoted_by_user_id=actor.id,
    )
    await notification_service.notify_role_change(
        session,
        target=target,
        actor_login=actor.login,
        promoted=True,
    )
    await session.commit()
    await session.refresh(target)
    return PromoteResponse(user=_to_list_item(target))


async def demote_user(
    session: AsyncSession,
    actor: User,
    target_user_id: int,
) -> DemoteResponse:
    if actor.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only")
    if actor.id == target_user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Use another admin to demote yourself",
        )

    target = await user_repository.get_by_id(session, target_user_id)
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if target.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already viewer")

    if not await can_demote_admin(session, actor, target):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only demote admins from your promotion branch",
        )

    await user_repository.set_role(session, target, role=UserRole.viewer)
    await notification_service.notify_role_change(
        session,
        target=target,
        actor_login=actor.login,
        promoted=False,
    )
    await session.commit()
    await session.refresh(target)
    return DemoteResponse(user=_to_list_item(target))


async def list_users(session: AsyncSession) -> list[UserListItem]:
    return await auth_service.list_users(session)
