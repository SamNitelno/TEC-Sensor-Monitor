from datetime import UTC, datetime
from typing import Literal

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.user import User
from app.repositories import contact_verification_repository, user_repository
from app.schemas.auth import (
    ContactSendCodesRequest,
    ContactSendCodesResponse,
    ContactVerifyCodeRequest,
    ContactVerifyCodeResponse,
    ProfileUpdateResponse,
    UserProfile,
)
from app.services import auth_service
from app.services.verification_delivery import (
    format_delivery_error,
    generate_verification_code,
    hash_verification_code,
    mask_email,
    mask_phone,
    normalize_email,
    normalize_phone,
    send_email_verification_code,
    send_sms_verification_code,
    validate_email,
    verify_code_hash,
)


def _needs_email_verification(user: User, email: str | None, clear_email: bool) -> bool:
    if clear_email or email is None:
        return False
    try:
        normalized = validate_email(email)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return not (user.email and normalize_email(user.email) == normalized)


def _needs_phone_verification(user: User, phone: str | None, clear_phone: bool) -> bool:
    if clear_phone or phone is None:
        return False
    try:
        normalized = normalize_phone(phone)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return not (user.phone and normalize_phone(user.phone) == normalized)


async def _validate_pending_values(
    session: AsyncSession,
    user: User,
    payload: ContactSendCodesRequest,
) -> tuple[str | None, str | None, str | None]:
    pending_login = payload.login.strip() if payload.login else None
    if pending_login == user.login:
        pending_login = None
    if pending_login is not None:
        existing = await user_repository.get_by_login(session, pending_login)
        if existing is not None and existing.id != user.id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Login already taken")

    pending_email = None
    if payload.email is not None and not payload.clear_email:
        pending_email = validate_email(payload.email)
        existing = await user_repository.get_by_email(session, pending_email)
        if existing is not None and existing.id != user.id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already taken")

    pending_phone = None
    if payload.phone is not None and not payload.clear_phone:
        pending_phone = normalize_phone(payload.phone)

    return pending_login, pending_email, pending_phone


async def _apply_batch(
    session: AsyncSession,
    user: User,
    batch,
) -> ProfileUpdateResponse:
    login_changed = batch.pending_login is not None
    await user_repository.update_profile(
        session,
        user,
        login=batch.pending_login,
        email=batch.pending_email if batch.pending_email is not None else None,
        clear_email=batch.clear_email,
        phone=batch.pending_phone if batch.pending_phone is not None else None,
        clear_phone=batch.clear_phone,
    )
    await contact_verification_repository.delete_batch(session, batch)
    await session.commit()
    await session.refresh(user)
    profile = auth_service._to_profile(user)
    new_token = None
    if login_changed:
        from app.core.security import create_access_token

        new_token = create_access_token(
            user_id=user.id,
            login=user.login,
            role=user.role.value,
        )
    return ProfileUpdateResponse(profile=profile, access_token=new_token)


async def send_contact_codes(
    session: AsyncSession,
    user: User,
    payload: ContactSendCodesRequest,
) -> ContactSendCodesResponse:
    pending_login, pending_email, pending_phone = await _validate_pending_values(
        session, user, payload
    )
    needs_email = _needs_email_verification(user, pending_email, payload.clear_email)
    needs_phone = _needs_phone_verification(user, pending_phone, payload.clear_phone)

    has_direct_changes = (
        pending_login is not None
        or payload.clear_email
        or payload.clear_phone
    )
    if not needs_email and not needs_phone:
        if not has_direct_changes:
            profile = auth_service._to_profile(user)
            return ContactSendCodesResponse(
                batch_id="",
                step="complete",
                destination_masked=None,
                message="Изменений не обнаружено",
                profile=profile,
            )
        await user_repository.update_profile(
            session,
            user,
            login=pending_login,
            clear_email=payload.clear_email,
            clear_phone=payload.clear_phone,
        )
        await session.commit()
        await session.refresh(user)
        profile = auth_service._to_profile(user)
        new_token = None
        if pending_login is not None:
            from app.core.security import create_access_token

            new_token = create_access_token(
                user_id=user.id,
                login=user.login,
                role=user.role.value,
            )
        return ContactSendCodesResponse(
            batch_id="",
            step="complete",
            destination_masked=None,
            message="Профиль сохранён",
            profile=profile,
            access_token=new_token,
        )

    email_code_hash = None
    phone_code_hash = None
    if needs_email:
        code = generate_verification_code()
        email_code_hash = hash_verification_code(code)
        batch = await contact_verification_repository.create_batch(
            session,
            user_id=user.id,
            pending_login=pending_login,
            pending_email=pending_email,
            pending_phone=pending_phone if needs_phone else None,
            clear_email=payload.clear_email,
            clear_phone=payload.clear_phone,
            email_code_hash=email_code_hash,
            phone_code_hash=None,
            ttl_minutes=settings.verification_code_ttl_minutes,
        )
        await session.commit()
        try:
            await send_email_verification_code(to_email=pending_email, code=code)
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Не удалось отправить код на email: {format_delivery_error(exc)}",
            ) from exc
        return ContactSendCodesResponse(
            batch_id=batch.id,
            step="email",
            destination_masked=mask_email(pending_email),
            message="Код отправлен на email",
        )

    code = generate_verification_code()
    phone_code_hash = hash_verification_code(code)
    batch = await contact_verification_repository.create_batch(
        session,
        user_id=user.id,
        pending_login=pending_login,
        pending_email=None,
        pending_phone=pending_phone,
        clear_email=payload.clear_email,
        clear_phone=payload.clear_phone,
        email_code_hash=None,
        phone_code_hash=phone_code_hash,
        ttl_minutes=settings.verification_code_ttl_minutes,
    )
    await session.commit()
    try:
        await send_sms_verification_code(to_phone=pending_phone, code=code)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Не удалось отправить SMS: {format_delivery_error(exc)}",
        ) from exc
    return ContactSendCodesResponse(
        batch_id=batch.id,
        step="phone",
        destination_masked=mask_phone(pending_phone),
        message="Код отправлен в SMS",
    )


async def _send_phone_code_for_batch(session: AsyncSession, batch) -> str:
    if batch.pending_phone is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone is not pending")
    code = generate_verification_code()
    batch.phone_code_hash = hash_verification_code(code)
    await session.flush()
    await send_sms_verification_code(to_phone=batch.pending_phone, code=code)
    return batch.pending_phone


async def verify_contact_code(
    session: AsyncSession,
    user: User,
    payload: ContactVerifyCodeRequest,
    *,
    channel: Literal["email", "phone"],
) -> ContactVerifyCodeResponse:
    batch = await contact_verification_repository.get_batch_for_user(
        session,
        batch_id=payload.batch_id,
        user_id=user.id,
    )
    if batch is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Verification batch not found")
    if batch.expires_at < datetime.now(UTC):
        raise HTTPException(status_code=status.HTTP_410_GONE, detail="Verification code expired")

    if channel == "email":
        if not verify_code_hash(payload.code, batch.email_code_hash):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid verification code")
        batch.email_verified = True
        batch.email_code_hash = None

        if batch.pending_phone is not None:
            try:
                phone = await _send_phone_code_for_batch(session, batch)
            except Exception as exc:
                await session.commit()
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Email подтверждён, но SMS не отправлено: {format_delivery_error(exc)}",
                ) from exc
            await session.commit()
            return ContactVerifyCodeResponse(
                step="phone",
                destination_masked=mask_phone(phone),
                message="Email подтверждён. Код отправлен в SMS",
            )

        result = await _apply_batch(session, user, batch)
        return ContactVerifyCodeResponse(
            step="complete",
            destination_masked=None,
            message="Профиль сохранён",
            profile=result.profile,
            access_token=result.access_token,
        )

    if not batch.email_verified and batch.pending_email is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Confirm email before phone",
        )
    if not verify_code_hash(payload.code, batch.phone_code_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid verification code")

    result = await _apply_batch(session, user, batch)
    return ContactVerifyCodeResponse(
        step="complete",
        destination_masked=None,
        message="Профиль сохранён",
        profile=result.profile,
        access_token=result.access_token,
    )
