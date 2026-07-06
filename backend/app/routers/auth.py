from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.api.public_access import (
    ensure_contact_verification_enabled,
    ensure_public_registration_enabled,
    ensure_verification_features_enabled,
    is_verification_delivery_ready,
)
from app.core.config import settings
from app.core.rate_limit import client_ip, limiter
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    AdminPasswordResetRequest,
    AdminPasswordResetResponse,
    AuthCapabilitiesResponse,
    ContactSendCodesRequest,
    ContactSendCodesResponse,
    ContactVerifyCodeRequest,
    ContactVerifyCodeResponse,
    LoginAvailabilityResponse,
    LoginRequest,
    PasswordChangeRequest,
    PasswordResetConfirmRequest,
    PasswordResetConfirmResponse,
    PasswordResetRequest,
    PasswordResetRequestResponse,
    ProfileUpdateRequest,
    ProfileUpdateResponse,
    RegisterRequest,
    TokenResponse,
    UserProfile,
)
from app.services import auth_service, contact_verification_service, password_reset_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/capabilities", response_model=AuthCapabilitiesResponse)
async def auth_capabilities() -> AuthCapabilitiesResponse:
    return AuthCapabilitiesResponse(
        public_registration=settings.allow_public_registration,
        password_reset=is_verification_delivery_ready(),
    )


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


@router.post("/password-reset/request", response_model=PasswordResetRequestResponse)
@limiter.limit(settings.auth_verify_rate_limit, key_func=client_ip)
async def password_reset_request(
    request: Request,
    payload: PasswordResetRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PasswordResetRequestResponse:
    return await password_reset_service.request_password_reset(db, payload)


@router.post("/password-reset/confirm", response_model=PasswordResetConfirmResponse)
@limiter.limit(settings.auth_verify_rate_limit, key_func=client_ip)
async def password_reset_confirm(
    request: Request,
    payload: PasswordResetConfirmRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PasswordResetConfirmResponse:
    return await password_reset_service.confirm_password_reset(db, payload)


@router.post("/me/contact/send-codes", response_model=ContactSendCodesResponse)
@limiter.limit(settings.auth_verify_rate_limit, key_func=client_ip)
async def send_contact_codes(
    request: Request,
    payload: ContactSendCodesRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> ContactSendCodesResponse:
    ensure_verification_features_enabled()
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
