import re

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
from app.services.verification_delivery import normalize_email, normalize_phone

_HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")


def validate_color(value: str | None) -> str | None:
    if value is None:
        return None
    if not _HEX_COLOR.match(value):
        raise ValueError("Color must be #RRGGBB")
    return value.upper()


async def get_by_id(session: AsyncSession, user_id: int) -> User | None:
    result = await session.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def get_by_login(session: AsyncSession, login: str) -> User | None:
    result = await session.execute(select(User).where(User.login == login))
    return result.scalar_one_or_none()


async def get_by_email(session: AsyncSession, email: str) -> User | None:
    normalized = normalize_email(email)
    result = await session.execute(
        select(User).where(func.lower(User.email) == normalized)
    )
    return result.scalar_one_or_none()


async def get_by_phone(session: AsyncSession, phone: str) -> User | None:
    normalized = normalize_phone(phone)
    result = await session.execute(select(User).where(User.phone == normalized))
    return result.scalar_one_or_none()


async def login_exists(session: AsyncSession, login: str) -> bool:
    user = await get_by_login(session, login)
    return user is not None


async def list_all(session: AsyncSession) -> list[User]:
    result = await session.execute(select(User).order_by(User.id))
    return list(result.scalars().all())


async def create(
    session: AsyncSession,
    *,
    login: str,
    password_hash: str,
    role: UserRole = UserRole.viewer,
    promoted_by_user_id: int | None = None,
    email: str | None = None,
    phone: str | None = None,
) -> User:
    user = User(
        login=login,
        password_hash=password_hash,
        role=role,
        promoted_by_user_id=promoted_by_user_id,
        email=email,
        phone=phone,
    )
    session.add(user)
    await session.flush()
    return user


async def update_profile(
    session: AsyncSession,
    user: User,
    *,
    login: str | None = None,
    email: str | None = None,
    clear_email: bool = False,
    phone: str | None = None,
    clear_phone: bool = False,
    password_hash: str | None = None,
) -> User:
    if login is not None:
        user.login = login
    if clear_email:
        user.email = None
    elif email is not None:
        user.email = normalize_email(email)
    if clear_phone:
        user.phone = None
    elif phone is not None:
        user.phone = phone
    if password_hash is not None:
        user.password_hash = password_hash
    await session.flush()
    return user


async def set_role(
    session: AsyncSession,
    user: User,
    *,
    role: UserRole,
    promoted_by_user_id: int | None = None,
) -> User:
    user.role = role
    if role == UserRole.admin:
        user.promoted_by_user_id = promoted_by_user_id
    else:
        user.promoted_by_user_id = None
    await session.flush()
    return user
