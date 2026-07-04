from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import sensor_repository, site_repository, workshop_repository
from app.schemas.site import WorkshopCreate, WorkshopResponse, WorkshopUpdate


def _to_response(workshop) -> WorkshopResponse:
    return WorkshopResponse(
        id=workshop.id,
        name=workshop.name,
        color=workshop.color,
        notifications_enabled=workshop.notifications_enabled,
        created_at=workshop.created_at,
    )


async def list_workshops(session: AsyncSession) -> list[WorkshopResponse]:
    workshops = await workshop_repository.list_all(session)
    return [_to_response(workshop) for workshop in workshops]


async def create_workshop(session: AsyncSession, payload: WorkshopCreate) -> WorkshopResponse:
    workshop = await workshop_repository.create(session, payload.name, color=payload.color)
    await session.commit()
    await session.refresh(workshop)
    return _to_response(workshop)


async def update_workshop(
    session: AsyncSession,
    workshop_id: int,
    payload: WorkshopUpdate,
) -> WorkshopResponse:
    workshop = await workshop_repository.get_by_id(session, workshop_id)
    if workshop is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workshop not found")
    workshop = await workshop_repository.update(
        session,
        workshop,
        name=payload.name,
        color=payload.color,
        clear_color=payload.clear_color,
        notifications_enabled=payload.notifications_enabled,
    )
    if payload.notifications_enabled is not None:
        await sensor_repository.set_notifications_enabled_for_workshop(
            session,
            workshop_id,
            enabled=payload.notifications_enabled,
        )
        sites = await site_repository.list_all(session, workshop_id=workshop_id)
        for site in sites:
            site.notifications_enabled = payload.notifications_enabled
    await session.commit()
    await session.refresh(workshop)
    return _to_response(workshop)


async def delete_workshop(session: AsyncSession, workshop_id: int) -> None:
    workshop = await workshop_repository.get_by_id(session, workshop_id)
    if workshop is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workshop not found")
    await workshop_repository.delete(session, workshop)
    await session.commit()


async def set_all_notifications_enabled(
    session: AsyncSession,
    *,
    enabled: bool,
) -> int:
    workshops = await workshop_repository.list_all(session)
    for workshop in workshops:
        workshop.notifications_enabled = enabled
    sites = await site_repository.list_all(session)
    for site in sites:
        site.notifications_enabled = enabled
    await sensor_repository.set_notifications_enabled_all(session, enabled=enabled)
    await session.commit()
    return len(workshops)
