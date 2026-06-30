from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.models.user import User, UserRole


async def ensure_admin_user(session: AsyncSession) -> None:
    """Create admin user from env if it does not exist (idempotent)."""
    result = await session.execute(select(User).where(User.login == settings.admin_login))
    existing = result.scalar_one_or_none()
    if existing is not None:
        return

    admin = User(
        login=settings.admin_login,
        password_hash=hash_password(settings.admin_password),
        role=UserRole.admin,
    )
    session.add(admin)
    await session.commit()
