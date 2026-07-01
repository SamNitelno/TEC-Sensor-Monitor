from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, verify_password
from app.repositories import user_repository
from app.schemas.auth import TokenResponse


async def login(session: AsyncSession, login_name: str, password: str) -> TokenResponse:
    user = await user_repository.get_by_login(session, login_name)
    if user is None or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid login or password",
        )
    token = create_access_token(user_id=user.id, login=user.login, role=user.role.value)
    return TokenResponse(access_token=token, role=user.role)
