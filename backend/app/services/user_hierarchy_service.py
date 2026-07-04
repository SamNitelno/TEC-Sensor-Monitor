from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.repositories import user_repository


async def can_demote_admin(
    session: AsyncSession,
    actor: User,
    target: User,
) -> bool:
    """Admin may demote another admin only if target is in actor's promotion tree."""
    if target.role != UserRole.admin:
        return False
    if target.promoted_by_user_id is None:
        return False
    if target.id == actor.id:
        return True

    current_id: int | None = target.promoted_by_user_id
    while current_id is not None:
        if current_id == actor.id:
            return True
        promoter = await user_repository.get_by_id(session, current_id)
        if promoter is None:
            return False
        current_id = promoter.promoted_by_user_id
    return False
