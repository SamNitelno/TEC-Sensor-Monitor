from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import site_repository, workshop_repository
from app.schemas.site import SiteCreate, SiteResponse, SiteUpdate


def _to_response(site) -> SiteResponse:
    if site.workshop_id is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Site {site.id} has no workshop assigned",
        )
    return SiteResponse(id=site.id, name=site.name, workshop_id=site.workshop_id)


async def list_sites(
    session: AsyncSession,
    workshop_id: int | None = None,
) -> list[SiteResponse]:
    sites = await site_repository.list_all(session, workshop_id=workshop_id)
    return [_to_response(site) for site in sites]


async def create_site(session: AsyncSession, payload: SiteCreate) -> SiteResponse:
    workshop = await workshop_repository.get_by_id(session, payload.workshop_id)
    if workshop is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workshop not found")
    site = await site_repository.create(session, payload.name, payload.workshop_id)
    await session.commit()
    await session.refresh(site)
    return _to_response(site)


async def update_site(session: AsyncSession, site_id: int, payload: SiteUpdate) -> SiteResponse:
    site = await site_repository.get_by_id(session, site_id)
    if site is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")
    if payload.workshop_id is not None:
        workshop = await workshop_repository.get_by_id(session, payload.workshop_id)
        if workshop is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workshop not found")
    site = await site_repository.update(
        session,
        site,
        name=payload.name,
        workshop_id=payload.workshop_id,
    )
    await session.commit()
    await session.refresh(site)
    return _to_response(site)


async def delete_site(session: AsyncSession, site_id: int) -> None:
    site = await site_repository.get_by_id(session, site_id)
    if site is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Site not found")
    await site_repository.delete(session, site)
    await session.commit()
