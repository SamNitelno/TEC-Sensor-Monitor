from datetime import UTC, datetime, timedelta

import jwt
import pytest
from httpx import AsyncClient

from app.core.config import settings


@pytest.mark.asyncio
async def test_login_returns_jwt_with_role_and_exp(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/login",
        json={"login": "admin", "password": "admin"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["role"] == "admin"

    payload = jwt.decode(body["access_token"], settings.jwt_secret, algorithms=["HS256"])
    assert payload["sub"] == "admin"
    assert payload["role"] == "admin"
    assert "exp" in payload
    assert datetime.fromtimestamp(payload["exp"], tz=UTC) > datetime.now(UTC)


@pytest.mark.asyncio
async def test_invalid_jwt_rejected(client: AsyncClient) -> None:
    response = await client.get(
        "/api/v1/sensors",
        headers={"Authorization": "Bearer not-a-valid-jwt"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_jwt_rejected(client: AsyncClient) -> None:
    expired = jwt.encode(
        {
            "sub": "admin",
            "uid": 1,
            "role": "admin",
            "exp": datetime.now(UTC) - timedelta(minutes=1),
        },
        settings.jwt_secret,
        algorithm="HS256",
    )
    response = await client.get(
        "/api/v1/sensors",
        headers={"Authorization": f"Bearer {expired}"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_viewer_forbidden_on_mutations(
    client: AsyncClient,
    viewer_token: str,
) -> None:
    headers = {"Authorization": f"Bearer {viewer_token}"}
    post_site = await client.post("/api/v1/sites", headers=headers, json={"name": "QA"})
    assert post_site.status_code == 403

    patch_sensor = await client.patch(
        "/api/v1/sensors/1",
        headers=headers,
        json={"name": "x"},
    )
    assert patch_sensor.status_code == 403

    delete_sensor = await client.delete("/api/v1/sensors/1", headers=headers)
    assert delete_sensor.status_code == 403


@pytest.mark.asyncio
async def test_admin_can_fetch_provisioning_token(
    client: AsyncClient,
    admin_token: str,
    test_sensor_token: tuple[int, str],
) -> None:
    sensor_id, expected_token = test_sensor_token
    headers = {"Authorization": f"Bearer {admin_token}"}
    response = await client.get(
        f"/api/v1/sensors/{sensor_id}/provisioning-token",
        headers=headers,
    )
    assert response.status_code == 200
    body = response.json()
    assert body["api_token"] == expected_token
    assert body["ingest_url"].endswith("/api/v1/ingest")


@pytest.mark.asyncio
async def test_viewer_cannot_fetch_provisioning_token(
    client: AsyncClient,
    viewer_token: str,
    test_sensor_token: tuple[int, str],
) -> None:
    sensor_id, _ = test_sensor_token
    headers = {"Authorization": f"Bearer {viewer_token}"}
    response = await client.get(
        f"/api/v1/sensors/{sensor_id}/provisioning-token",
        headers=headers,
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_admin_can_create_site(client: AsyncClient, admin_token: str) -> None:
    headers = {"Authorization": f"Bearer {admin_token}"}
    name = f"QA-site-{datetime.now(UTC).timestamp()}"
    response = await client.post("/api/v1/sites", headers=headers, json={"name": name})
    assert response.status_code == 201
    assert response.json()["name"] == name
