from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.site import Site


async def list_all(session: AsyncSession, workshop_id: int | None = None) -> list[Site]:
    query = select(Site).order_by(Site.id)
    if workshop_id is not None:
        query = query.where(Site.workshop_id == workshop_id)
    result = await session.execute(query)
    return list(result.scalars().all())


async def get_by_id(session: AsyncSession, site_id: int) -> Site | None:
    result = await session.execute(select(Site).where(Site.id == site_id))
    return result.scalar_one_or_none()


async def create(session: AsyncSession, name: str, workshop_id: int) -> Site:
    site = Site(name=name, workshop_id=workshop_id)
    session.add(site)
    await session.flush()
    return site


async def update(
    session: AsyncSession,
    site: Site,
    *,
    name: str | None = None,
    workshop_id: int | None = None,
) -> Site:
    if name is not None:
        site.name = name
    if workshop_id is not None:
        site.workshop_id = workshop_id
    await session.flush()
    return site


async def delete(session: AsyncSession, site: Site) -> None:
    await session.delete(site)
