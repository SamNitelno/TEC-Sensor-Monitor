from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.models.user import User, UserRole


async def ensure_admin_user(session: AsyncSession) -> None:
    """Create admin and viewer users from env if they do not exist (idempotent)."""
    result = await session.execute(select(User).where(User.login == settings.admin_login))
    if result.scalar_one_or_none() is None:
        session.add(
            User(
                login=settings.admin_login,
                password_hash=hash_password(settings.admin_password),
                role=UserRole.admin,
            )
        )

    result = await session.execute(select(User).where(User.login == settings.viewer_login))
    if result.scalar_one_or_none() is None:
        session.add(
            User(
                login=settings.viewer_login,
                password_hash=hash_password(settings.viewer_password),
                role=UserRole.viewer,
            )
        )

    await session.commit()
