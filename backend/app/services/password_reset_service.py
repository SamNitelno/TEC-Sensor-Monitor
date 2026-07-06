import uuid
from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.public_access import FEATURE_IN_DEVELOPMENT
from app.core.config import settings
from app.core.password_validation import validate_password
from app.core.security import hash_password
from app.models.user import User, UserRole
from app.repositories import password_reset_repository, user_repository
from app.schemas.auth import (
    AdminPasswordResetRequest,
    PasswordResetConfirmRequest,
    PasswordResetConfirmResponse,
    PasswordResetRequest,
    PasswordResetRequestResponse,
)
from app.services.verification_delivery import (
    delivery_channel_ready,
    format_delivery_error,
    generate_verification_code,
    hash_verification_code,
    mask_email,
    mask_phone,
    normalize_email,
    normalize_phone,
    send_email_verification_code,
    send_password_reset_email,
    send_password_reset_sms,
    send_sms_verification_code,
    validate_email,
    verification_delivery_ready,
    verify_code_hash,
)

_GENERIC_RESET_MESSAGE = (
    "Если указанный контакт привязан к аккаунту, мы отправили код подтверждения."
)
_INVALID_CODE_MESSAGE = "Неверный или просроченный код подтверждения"


async def _find_user_by_contact(
    session: AsyncSession,
    *,
    email: str | None,
    phone: str | None,
) -> User | None:
    if email:
        return await user_repository.get_by_email(session, email)
    if phone:
        return await user_repository.get_by_phone(session, phone)
    return None


async def request_password_reset(
    session: AsyncSession,
    payload: PasswordResetRequest,
) -> PasswordResetRequestResponse:
    if not verification_delivery_ready():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=FEATURE_IN_DEVELOPMENT,
        )

    email = None
    phone = None
    channel = None
    if payload.email:
        try:
            email = validate_email(payload.email)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(exc),
            ) from exc
        channel = "email"
        if not delivery_channel_ready("email"):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Отправка email не настроена. Обратитесь к администратору.",
            )
    elif payload.phone:
        try:
            phone = normalize_phone(payload.phone)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(exc),
            ) from exc
        channel = "phone"
        if not delivery_channel_ready("phone"):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Отправка SMS не настроена. Обратитесь к администратору.",
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Укажите email или телефон",
        )

    batch_id = str(uuid.uuid4())
    user = await _find_user_by_contact(session, email=email, phone=phone)

    if user is not None and user.is_active:
        await password_reset_repository.delete_batches_for_user(session, user.id)
        code = generate_verification_code()
        destination = email or phone or ""
        batch = await password_reset_repository.create_batch(
            session,
            user_id=user.id,
            channel=channel,
            destination=destination,
            code_hash=hash_verification_code(code),
            ttl_minutes=settings.verification_code_ttl_minutes,
        )
        batch_id = batch.id
        await session.commit()
        try:
            if channel == "email":
                await send_password_reset_email(to_email=destination, code=code)
            else:
                await send_password_reset_sms(to_phone=destination, code=code)
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Не удалось отправить код: {format_delivery_error(exc)}",
            ) from exc
    else:
        await session.commit()

    masked = mask_email(email) if email else mask_phone(phone or "")
    return PasswordResetRequestResponse(
        batch_id=batch_id,
        destination_masked=masked,
        message=_GENERIC_RESET_MESSAGE,
    )


async def confirm_password_reset(
    session: AsyncSession,
    payload: PasswordResetConfirmRequest,
) -> PasswordResetConfirmResponse:
    if not verification_delivery_ready():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=FEATURE_IN_DEVELOPMENT,
        )

    try:
        validate_password(payload.new_password)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    batch = await password_reset_repository.get_active_batch(
        session, batch_id=payload.batch_id
    )
    if batch is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=_INVALID_CODE_MESSAGE)
    if batch.expires_at < datetime.now(UTC):
        raise HTTPException(status_code=status.HTTP_410_GONE, detail=_INVALID_CODE_MESSAGE)
    if batch.failed_attempts >= settings.verification_max_attempts:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Слишком много попыток. Запросите новый код.",
        )
    if not verify_code_hash(payload.code, batch.code_hash):
        batch.failed_attempts += 1
        await session.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=_INVALID_CODE_MESSAGE)

    user = await user_repository.get_by_id(session, batch.user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=_INVALID_CODE_MESSAGE)

    batch.consumed_at = datetime.now(UTC)
    await user_repository.update_profile(
        session,
        user,
        password_hash=hash_password(payload.new_password),
    )
    await password_reset_repository.delete_batches_for_user(session, user.id)
    await session.commit()

    return PasswordResetConfirmResponse(message="Пароль успешно изменён. Войдите с новым паролем.")


async def admin_reset_password(
    session: AsyncSession,
    *,
    actor: User,
    target_user_id: int,
    payload: AdminPasswordResetRequest,
) -> None:
    if actor.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only")

    target = await user_repository.get_by_id(session, target_user_id)
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    try:
        validate_password(payload.new_password)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    await user_repository.update_profile(
        session,
        target,
        password_hash=hash_password(payload.new_password),
    )
    await password_reset_repository.delete_batches_for_user(session, target.id)
    await session.commit()
