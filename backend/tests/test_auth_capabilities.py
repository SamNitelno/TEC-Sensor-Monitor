import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_auth_capabilities(client: AsyncClient) -> None:
    response = await client.get("/api/v1/auth/capabilities")
    assert response.status_code == 200
    data = response.json()
    assert "public_registration" in data
    assert "password_reset" in data
    assert isinstance(data["public_registration"], bool)
    assert isinstance(data["password_reset"], bool)
