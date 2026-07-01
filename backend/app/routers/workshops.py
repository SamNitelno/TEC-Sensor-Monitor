from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_admin, require_viewer
from app.db.session import get_db
from app.models.user import User
from app.schemas.site import WorkshopCreate, WorkshopResponse, WorkshopUpdate
from app.services import workshop_service

router = APIRouter(prefix="/workshops", tags=["workshops"])


@router.get("", response_model=list[WorkshopResponse])
async def list_workshops(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_viewer)],
    site_id: Annotated[int | None, Query()] = None,
) -> list[WorkshopResponse]:
    return await workshop_service.list_workshops(db, site_id=site_id)


@router.post("", response_model=WorkshopResponse, status_code=status.HTTP_201_CREATED)
async def create_workshop(
    payload: WorkshopCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> WorkshopResponse:
    return await workshop_service.create_workshop(db, payload)


@router.patch("/{workshop_id}", response_model=WorkshopResponse)
async def update_workshop(
    workshop_id: int,
    payload: WorkshopUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> WorkshopResponse:
    return await workshop_service.update_workshop(db, workshop_id, payload)


@router.delete("/{workshop_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_workshop(
    workshop_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> Response:
    await workshop_service.delete_workshop(db, workshop_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
