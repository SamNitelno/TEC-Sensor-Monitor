from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.site import Site


async def list_all(session: AsyncSession) -> list[Site]:
    result = await session.execute(select(Site).order_by(Site.id))
    return list(result.scalars().all())


async def get_by_id(session: AsyncSession, site_id: int) -> Site | None:
    result = await session.execute(select(Site).where(Site.id == site_id))
    return result.scalar_one_or_none()


async def create(session: AsyncSession, name: str) -> Site:
    site = Site(name=name)
    session.add(site)
    await session.flush()
    return site


async def update(session: AsyncSession, site: Site, name: str) -> Site:
    site.name = name
    await session.flush()
    return site


async def delete(session: AsyncSession, site: Site) -> None:
    await session.delete(site)
