"""Verification feature gates and delivery readiness."""

from fastapi import HTTPException, status

from app.core.config import settings

FEATURE_IN_DEVELOPMENT = "Функция в разработке, приносим извинения"


def is_verification_delivery_ready() -> bool:
    from app.services.verification_delivery import verification_delivery_ready

    return verification_delivery_ready()


def ensure_public_registration_enabled() -> None:
    if not settings.allow_public_registration:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")


def ensure_verification_features_enabled() -> None:
    """Contact verification and password reset require configured delivery."""
    if not is_verification_delivery_ready():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=FEATURE_IN_DEVELOPMENT,
        )


# Backwards-compatible alias used by contact routes
ensure_contact_verification_enabled = ensure_verification_features_enabled
