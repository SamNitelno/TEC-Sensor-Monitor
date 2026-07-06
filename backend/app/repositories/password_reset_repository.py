import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.password_reset import PasswordResetBatch


async def create_batch(
    session: AsyncSession,
    *,
    user_id: int,
    channel: str,
    destination: str,
    code_hash: str,
    ttl_minutes: int,
) -> PasswordResetBatch:
    batch = PasswordResetBatch(
        id=str(uuid.uuid4()),
        user_id=user_id,
        channel=channel,
        destination=destination,
        code_hash=code_hash,
        expires_at=datetime.now(UTC) + timedelta(minutes=ttl_minutes),
    )
    session.add(batch)
    await session.flush()
    return batch


async def get_active_batch(
    session: AsyncSession,
    *,
    batch_id: str,
) -> PasswordResetBatch | None:
    result = await session.execute(
        select(PasswordResetBatch).where(
            PasswordResetBatch.id == batch_id,
            PasswordResetBatch.consumed_at.is_(None),
        )
    )
    return result.scalar_one_or_none()


async def delete_batches_for_user(session: AsyncSession, user_id: int) -> None:
    result = await session.execute(
        select(PasswordResetBatch).where(PasswordResetBatch.user_id == user_id)
    )
    for batch in result.scalars():
        await session.delete(batch)
