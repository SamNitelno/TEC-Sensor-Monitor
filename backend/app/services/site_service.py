from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import site_repository
from app.schemas.site import SiteCreate, SiteResponse, SiteUpdate


def _to_response(site) -> SiteResponse:
    return SiteResponse(id=site.id, name=site.name)


async def list_sites(session: AsyncSession) -> list[SiteResponse]:
    sites = await site_repository.list_all(session)
    return [_to_response(site) for site in sites]


async def create_site(session: AsyncSession, payload: SiteCreate) -> SiteResponse:
    site = await site_repository.create(session, payload.name)
    await session.commit()
    await session.refresh(site)
    return _to_response(site)


async def update_site(session: AsyncSession, site_id: int, payload: SiteUpdate) -> SiteResponse:
    site = await site_repository.get_by_id(session, site_id)
    if site is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")
    site = await site_repository.update(session, site, payload.name)
    await session.commit()
    await session.refresh(site)
    return _to_response(site)


async def delete_site(session: AsyncSession, site_id: int) -> None:
    site = await site_repository.get_by_id(session, site_id)
    if site is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")
    await site_repository.delete(session, site)
    await session.commit()
