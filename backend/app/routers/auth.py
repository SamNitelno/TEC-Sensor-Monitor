from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.api.public_access import (
    ensure_contact_verification_enabled,
    ensure_public_registration_enabled,
)
from app.core.config import settings
from app.core.rate_limit import client_ip, limiter
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    ContactSendCodesRequest,
    ContactSendCodesResponse,
    ContactVerifyCodeRequest,
    ContactVerifyCodeResponse,
    LoginAvailabilityResponse,
    LoginRequest,
    PasswordChangeRequest,
    ProfileUpdateRequest,
    ProfileUpdateResponse,
    RegisterRequest,
    TokenResponse,
    UserProfile,
)
from app.services import auth_service, contact_verification_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
@limiter.limit(settings.auth_login_rate_limit, key_func=client_ip)
async def login(
    request: Request,
    payload: LoginRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> TokenResponse:
    return await auth_service.login(db, payload.login, payload.password)


@router.post("/register", response_model=TokenResponse, status_code=201)
@limiter.limit(settings.auth_register_rate_limit, key_func=client_ip)
async def register(
    request: Request,
    payload: RegisterRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> TokenResponse:
    ensure_public_registration_enabled()
    return await auth_service.register(db, payload)


@router.get("/check-login", response_model=LoginAvailabilityResponse)
@limiter.limit(settings.auth_login_rate_limit, key_func=client_ip)
async def check_login(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    login: Annotated[str, Query(min_length=3, max_length=64)],
) -> LoginAvailabilityResponse:
    ensure_public_registration_enabled()
    return await auth_service.check_login_available(db, login)


@router.get("/me", response_model=UserProfile)
async def get_me(
    user: Annotated[User, Depends(get_current_user)],
) -> UserProfile:
    return await auth_service.get_profile(user)


@router.patch("/me", response_model=ProfileUpdateResponse)
async def update_me(
    payload: ProfileUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> ProfileUpdateResponse:
    return await auth_service.update_profile(db, user, payload)


@router.post("/me/password", response_model=UserProfile)
async def change_password(
    payload: PasswordChangeRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> UserProfile:
    return await auth_service.change_password(db, user, payload)


@router.post("/me/contact/send-codes", response_model=ContactSendCodesResponse)
@limiter.limit(settings.auth_verify_rate_limit, key_func=client_ip)
async def send_contact_codes(
    request: Request,
    payload: ContactSendCodesRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> ContactSendCodesResponse:
    ensure_contact_verification_enabled()
    return await contact_verification_service.send_contact_codes(db, user, payload)


@router.post("/me/contact/verify-email", response_model=ContactVerifyCodeResponse)
@limiter.limit(settings.auth_verify_rate_limit, key_func=client_ip)
async def verify_contact_email(
    request: Request,
    payload: ContactVerifyCodeRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> ContactVerifyCodeResponse:
    ensure_contact_verification_enabled()
    return await contact_verification_service.verify_contact_code(
        db, user, payload, channel="email"
    )


@router.post("/me/contact/verify-phone", response_model=ContactVerifyCodeResponse)
@limiter.limit(settings.auth_verify_rate_limit, key_func=client_ip)
async def verify_contact_email_phone(
    request: Request,
    payload: ContactVerifyCodeRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> ContactVerifyCodeResponse:
    ensure_contact_verification_enabled()
    return await contact_verification_service.verify_contact_code(
        db, user, payload, channel="phone"
    )
