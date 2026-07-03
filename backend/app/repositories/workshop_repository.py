from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.workshop import Workshop


async def list_all(session: AsyncSession) -> list[Workshop]:
    result = await session.execute(select(Workshop).order_by(Workshop.id))
    return list(result.scalars().all())


async def get_by_id(session: AsyncSession, workshop_id: int) -> Workshop | None:
    result = await session.execute(select(Workshop).where(Workshop.id == workshop_id))
    return result.scalar_one_or_none()


async def create(session: AsyncSession, name: str) -> Workshop:
    workshop = Workshop(name=name)
    session.add(workshop)
    await session.flush()
    return workshop


async def update(
    session: AsyncSession,
    workshop: Workshop,
    *,
    name: str | None = None,
) -> Workshop:
    if name is not None:
        workshop.name = name
    await session.flush()
    return workshop


async def delete(session: AsyncSession, workshop: Workshop) -> None:
    await session.delete(workshop)
