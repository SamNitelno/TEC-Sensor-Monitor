from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.password_validation import validate_password
from app.core.security import hash_password, verify_password
from app.models.user import User, UserRole


async def _ensure_bootstrap_user(
    session: AsyncSession,
    *,
    login: str,
    password: str,
    role: UserRole,
) -> None:
    result = await session.execute(select(User).where(User.login == login))
    user = result.scalar_one_or_none()
    password_hash = hash_password(password)
    if user is None:
        session.add(
            User(
                login=login,
                password_hash=password_hash,
                role=role,
            )
        )
        return
    if not verify_password(password, user.password_hash):
        user.password_hash = password_hash


async def ensure_admin_user(session: AsyncSession) -> None:
    """Create or sync admin/viewer users from env (idempotent)."""
    if settings.is_production:
        validate_password(settings.admin_password)
        validate_password(settings.viewer_password)

    await _ensure_bootstrap_user(
        session,
        login=settings.admin_login,
        password=settings.admin_password,
        role=UserRole.admin,
    )
    await _ensure_bootstrap_user(
        session,
        login=settings.viewer_login,
        password=settings.viewer_password,
        role=UserRole.viewer,
    )

    await session.commit()
