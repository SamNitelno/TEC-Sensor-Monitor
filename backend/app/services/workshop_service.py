from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import workshop_repository
from app.schemas.site import WorkshopCreate, WorkshopResponse, WorkshopUpdate


def _to_response(workshop) -> WorkshopResponse:
    return WorkshopResponse(id=workshop.id, name=workshop.name)


async def list_workshops(session: AsyncSession) -> list[WorkshopResponse]:
    workshops = await workshop_repository.list_all(session)
    return [_to_response(workshop) for workshop in workshops]


async def create_workshop(session: AsyncSession, payload: WorkshopCreate) -> WorkshopResponse:
    workshop = await workshop_repository.create(session, payload.name)
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
    workshop = await workshop_repository.update(session, workshop, name=payload.name)
    await session.commit()
    await session.refresh(workshop)
    return _to_response(workshop)


async def delete_workshop(session: AsyncSession, workshop_id: int) -> None:
    workshop = await workshop_repository.get_by_id(session, workshop_id)
    if workshop is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workshop not found")
    await workshop_repository.delete(session, workshop)
    await session.commit()
