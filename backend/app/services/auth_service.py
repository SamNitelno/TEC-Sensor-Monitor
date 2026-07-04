from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.password_validation import validate_password
from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User, UserRole
from app.repositories import user_repository
from app.schemas.auth import (
    LoginAvailabilityResponse,
    PasswordChangeRequest,
    ProfileUpdateRequest,
    ProfileUpdateResponse,
    RegisterRequest,
    TokenResponse,
    UserListItem,
    UserProfile,
)


def _to_profile(user: User) -> UserProfile:
    return UserProfile(
        id=user.id,
        login=user.login,
        role=user.role,
        email=user.email,
        phone=user.phone,
        promoted_by_user_id=user.promoted_by_user_id,
        created_at=user.created_at,
    )


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


async def login(session: AsyncSession, login_name: str, password: str) -> TokenResponse:
    user = await user_repository.get_by_login(session, login_name)
    if user is None or not user.is_active or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid login or password",
        )
    token = create_access_token(user_id=user.id, login=user.login, role=user.role.value)
    return TokenResponse(access_token=token, role=user.role)


async def register(session: AsyncSession, payload: RegisterRequest) -> TokenResponse:
    try:
        validate_password(payload.password)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    if await user_repository.login_exists(session, payload.login):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Login already taken")

    user = await user_repository.create(
        session,
        login=payload.login,
        password_hash=hash_password(payload.password),
        role=UserRole.viewer,
    )
    await session.commit()
    await session.refresh(user)
    token = create_access_token(user_id=user.id, login=user.login, role=user.role.value)
    return TokenResponse(access_token=token, role=user.role)


async def check_login_available(session: AsyncSession, login: str) -> LoginAvailabilityResponse:
    available = not await user_repository.login_exists(session, login)
    return LoginAvailabilityResponse(login=login, available=available)


async def get_profile(user: User) -> UserProfile:
    return _to_profile(user)


async def update_profile(
    session: AsyncSession,
    user: User,
    payload: ProfileUpdateRequest,
) -> ProfileUpdateResponse:
    login_changed = payload.login is not None and payload.login != user.login
    if login_changed:
        existing = await user_repository.get_by_login(session, payload.login)
        if existing is not None and existing.id != user.id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Login already taken")

    if payload.email is not None and payload.email != user.email:
        existing = await user_repository.get_by_email(session, payload.email)
        if existing is not None and existing.id != user.id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already taken")

    await user_repository.update_profile(
        session,
        user,
        login=payload.login,
        email=payload.email,
        clear_email=payload.clear_email,
        phone=payload.phone,
        clear_phone=payload.clear_phone,
    )
    await session.commit()
    await session.refresh(user)
    profile = _to_profile(user)
    new_token = None
    if login_changed:
        new_token = create_access_token(
            user_id=user.id,
            login=user.login,
            role=user.role.value,
        )
    return ProfileUpdateResponse(profile=profile, access_token=new_token)


async def change_password(
    session: AsyncSession,
    user: User,
    payload: PasswordChangeRequest,
) -> UserProfile:
    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Wrong current password")
    try:
        validate_password(payload.new_password)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    await user_repository.update_profile(
        session,
        user,
        password_hash=hash_password(payload.new_password),
    )
    await session.commit()
    await session.refresh(user)
    return _to_profile(user)


async def list_users(session: AsyncSession) -> list[UserListItem]:
    users = await user_repository.list_all(session)
    return [_to_list_item(user) for user in users]
