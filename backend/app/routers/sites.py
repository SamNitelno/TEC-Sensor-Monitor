from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_admin, require_viewer
from app.db.session import get_db
from app.models.user import User
from app.schemas.site import SiteCreate, SiteResponse, SiteUpdate
from app.services import site_service

router = APIRouter(prefix="/sites", tags=["sites"])


@router.get("", response_model=list[SiteResponse])
async def list_sites(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_viewer)],
) -> list[SiteResponse]:
    return await site_service.list_sites(db)


@router.post("", response_model=SiteResponse, status_code=status.HTTP_201_CREATED)
async def create_site(
    payload: SiteCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> SiteResponse:
    return await site_service.create_site(db, payload)


@router.patch("/{site_id}", response_model=SiteResponse)
async def update_site(
    site_id: int,
    payload: SiteUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> SiteResponse:
    return await site_service.update_site(db, site_id, payload)


@router.delete("/{site_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_site(
    site_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> Response:
    await site_service.delete_site(db, site_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
