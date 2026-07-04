from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_notification import UserNotification


async def create(
    session: AsyncSession,
    *,
    user_id: int,
    message: str,
    kind: str,
) -> UserNotification:
    notification = UserNotification(
        user_id=user_id,
        message=message,
        kind=kind,
        created_at=datetime.now(UTC),
    )
    session.add(notification)
    await session.flush()
    return notification


async def list_unread_for_user(
    session: AsyncSession,
    user_id: int,
    *,
    limit: int = 50,
) -> list[UserNotification]:
    result = await session.execute(
        select(UserNotification)
        .where(
            UserNotification.user_id == user_id,
            UserNotification.read_at.is_(None),
        )
        .order_by(UserNotification.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def mark_read(
    session: AsyncSession,
    notification: UserNotification,
) -> None:
    notification.read_at = datetime.now(UTC)


async def count_unread_for_user(session: AsyncSession, user_id: int) -> int:
    from sqlalchemy import func

    result = await session.execute(
        select(func.count())
        .select_from(UserNotification)
        .where(
            UserNotification.user_id == user_id,
            UserNotification.read_at.is_(None),
        )
    )
    return int(result.scalar_one())
