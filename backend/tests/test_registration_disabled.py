import pytest
from httpx import AsyncClient

from app.api import public_access
from app.core.config import settings


@pytest.mark.asyncio
async def test_register_disabled_when_public_registration_off(
    client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "allow_public_registration", False)
    monkeypatch.setattr(
        public_access,
        "ensure_public_registration_enabled",
        public_access.ensure_public_registration_enabled,
    )

    response = await client.post(
        "/api/v1/auth/register",
        json={"login": "newuser999", "password": "password123"},
    )
    assert response.status_code == 404
