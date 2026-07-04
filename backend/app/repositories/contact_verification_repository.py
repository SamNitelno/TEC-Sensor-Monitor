from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.contact_verification import ContactVerificationBatch


async def delete_user_batches(session: AsyncSession, user_id: int) -> None:
    await session.execute(
        delete(ContactVerificationBatch).where(ContactVerificationBatch.user_id == user_id)
    )


async def create_batch(
    session: AsyncSession,
    *,
    user_id: int,
    pending_login: str | None,
    pending_email: str | None,
    pending_phone: str | None,
    clear_email: bool,
    clear_phone: bool,
    email_code_hash: str | None,
    phone_code_hash: str | None,
    ttl_minutes: int,
) -> ContactVerificationBatch:
    await delete_user_batches(session, user_id)
    batch = ContactVerificationBatch(
        id=str(uuid4()),
        user_id=user_id,
        pending_login=pending_login,
        pending_email=pending_email,
        pending_phone=pending_phone,
        clear_email=clear_email,
        clear_phone=clear_phone,
        email_code_hash=email_code_hash,
        phone_code_hash=phone_code_hash,
        email_verified=False,
        expires_at=datetime.now(UTC) + timedelta(minutes=ttl_minutes),
    )
    session.add(batch)
    await session.flush()
    return batch


async def get_batch_for_user(
    session: AsyncSession,
    *,
    batch_id: str,
    user_id: int,
) -> ContactVerificationBatch | None:
    result = await session.execute(
        select(ContactVerificationBatch).where(
            ContactVerificationBatch.id == batch_id,
            ContactVerificationBatch.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()


async def delete_batch(session: AsyncSession, batch: ContactVerificationBatch) -> None:
    await session.delete(batch)
