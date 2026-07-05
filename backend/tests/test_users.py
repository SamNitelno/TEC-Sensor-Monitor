import uuid

import pytest
from httpx import AsyncClient

from app.services.verification_delivery import get_test_code


@pytest.mark.asyncio
async def test_register_and_login(client: AsyncClient):
    login = f"testuser_reg_{uuid.uuid4().hex[:8]}"
    password = "Pass1234"

    check = await client.get("/api/v1/auth/check-login", params={"login": login})
    assert check.status_code == 200
    assert check.json()["available"] is True

    reg = await client.post(
        "/api/v1/auth/register",
        json={"login": login, "password": password},
    )
    assert reg.status_code == 201
    assert reg.json()["role"] == "viewer"

    check2 = await client.get("/api/v1/auth/check-login", params={"login": login})
    assert check2.json()["available"] is False

    bad = await client.post(
        "/api/v1/auth/register",
        json={"login": login, "password": "12345678"},
    )
    assert bad.status_code in (400, 422)


@pytest.mark.asyncio
async def test_profile_update(client: AsyncClient, admin_token: str):
    headers = {"Authorization": f"Bearer {admin_token}"}
    me = await client.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["login"] == "admin"

    send = await client.post(
        "/api/v1/auth/me/contact/send-codes",
        headers=headers,
        json={"email": "admin@test.local"},
    )
    assert send.status_code == 200
    batch_id = send.json()["batch_id"]
    code = get_test_code("email", "admin@test.local")
    assert code is not None

    verified = await client.post(
        "/api/v1/auth/me/contact/verify-email",
        headers=headers,
        json={"batch_id": batch_id, "code": code},
    )
    assert verified.status_code == 200
    assert verified.json()["profile"]["email"] == "admin@test.local"


@pytest.mark.asyncio
async def test_promote_demote_hierarchy(client: AsyncClient, admin_token: str):
    headers = {"Authorization": f"Bearer {admin_token}"}
    login = f"viewer_promote_{uuid.uuid4().hex[:8]}"

    reg = await client.post(
        "/api/v1/auth/register",
        json={"login": login, "password": "Pass1234"},
    )
    assert reg.status_code == 201
    user_id = (
        await client.get("/api/v1/users", headers=headers)
    ).json()
    promoted_id = next(u["id"] for u in user_id if u["login"] == login)

    promote = await client.post(f"/api/v1/users/{promoted_id}/promote", headers=headers)
    assert promote.status_code == 200
    assert promote.json()["user"]["role"] == "admin"

    demote = await client.post(f"/api/v1/users/{promoted_id}/demote", headers=headers)
    assert demote.status_code == 200
    assert demote.json()["user"]["role"] == "viewer"


@pytest.mark.asyncio
async def test_entity_colors(client: AsyncClient, admin_token: str):
    headers = {"Authorization": f"Bearer {admin_token}"}
    workshop = await client.post(
        "/api/v1/workshops",
        headers=headers,
        json={"name": "Color WS", "color": "#FF0000"},
    )
    assert workshop.status_code == 201
    assert workshop.json()["color"] == "#FF0000"
