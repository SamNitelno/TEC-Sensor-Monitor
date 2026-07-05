from fastapi import HTTPException, status

from app.core.config import settings


def ensure_public_registration_enabled() -> None:
    if not settings.allow_public_registration:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")


def ensure_contact_verification_enabled() -> None:
    if not settings.allow_public_registration:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
