import sys

from app.core.config import Settings
from app.core.password_validation import validate_password

_WEAK_SECRETS = frozenset(
    {
        "change-me-to-a-long-random-string",
        "change-me",
        "changeme",
        "secret",
        "password",
        "admin",
        "viewer",
        "tek_secret",
        "jwt_secret",
        "test",
        "12345678",
    }
)


def _is_weak(value: str) -> bool:
    normalized = value.strip().lower()
    if not normalized:
        return True
    if normalized in _WEAK_SECRETS:
        return True
    if len(normalized) < 16 and normalized in {"admin", "viewer", "password"}:
        return True
    return False


def validate_production_settings(settings: Settings) -> None:
    if settings.app_env.strip().lower() != "production":
        return

    errors: list[str] = []

    if _is_weak(settings.jwt_secret) or len(settings.jwt_secret) < 32:
        errors.append("JWT_SECRET must be at least 32 characters and not a placeholder")

    if _is_weak(settings.admin_password):
        errors.append("ADMIN_PASSWORD is weak or uses a placeholder value")
    else:
        try:
            validate_password(settings.admin_password)
        except ValueError as exc:
            errors.append(f"ADMIN_PASSWORD: {exc}")

    if _is_weak(settings.viewer_password):
        errors.append("VIEWER_PASSWORD is weak or uses a placeholder value")
    else:
        try:
            validate_password(settings.viewer_password)
        except ValueError as exc:
            errors.append(f"VIEWER_PASSWORD: {exc}")

    if not settings.cors_origins.strip():
        errors.append("CORS_ORIGINS must be set explicitly in production")

    if settings.verification_delivery_mode.strip().lower() == "production":
        errors.append(
            "VERIFICATION_DELIVERY_MODE=production is disabled for LAN prod; use log or test"
        )

    if errors:
        for message in errors:
            print(f"PRODUCTION CONFIG ERROR: {message}", file=sys.stderr)
        raise SystemExit(1)
