from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.workshop import Workshop


async def list_all(session: AsyncSession, site_id: int | None = None) -> list[Workshop]:
    query = select(Workshop).order_by(Workshop.id)
    if site_id is not None:
        query = query.where(Workshop.site_id == site_id)
    result = await session.execute(query)
    return list(result.scalars().all())


async def get_by_id(session: AsyncSession, workshop_id: int) -> Workshop | None:
    result = await session.execute(select(Workshop).where(Workshop.id == workshop_id))
    return result.scalar_one_or_none()


async def create(session: AsyncSession, name: str, site_id: int) -> Workshop:
    workshop = Workshop(name=name, site_id=site_id)
    session.add(workshop)
    await session.flush()
    return workshop


async def update(
    session: AsyncSession,
    workshop: Workshop,
    *,
    name: str | None = None,
    site_id: int | None = None,
) -> Workshop:
    if name is not None:
        workshop.name = name
    if site_id is not None:
        workshop.site_id = site_id
    await session.flush()
    return workshop


async def delete(session: AsyncSession, workshop: Workshop) -> None:
    await session.delete(workshop)
