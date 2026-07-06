import uuid

import pytest
from httpx import AsyncClient

from app.services.verification_delivery import get_test_code


async def _register_user(client: AsyncClient) -> tuple[str, str]:
    login = f"reset_user_{uuid.uuid4().hex[:8]}"
    password = "StartPass99"
    reg = await client.post(
        "/api/v1/auth/register",
        json={"login": login, "password": password},
    )
    assert reg.status_code == 201, reg.text
    return login, reg.json()["access_token"]


@pytest.mark.asyncio
async def test_password_reset_request_same_response_unknown_user(
    client: AsyncClient,
) -> None:
    unknown = await client.post(
        "/api/v1/auth/password-reset/request",
        json={"email": f"nobody_{uuid.uuid4().hex[:8]}@test.local"},
    )
    assert unknown.status_code == 200
    assert "batch_id" in unknown.json()
    assert "message" in unknown.json()


@pytest.mark.asyncio
async def test_password_reset_flow_with_test_delivery(client: AsyncClient) -> None:
    login, token = await _register_user(client)
    headers = {"Authorization": f"Bearer {token}"}

    suffix = uuid.uuid4().hex[:8]
    email = f"reset_{suffix}@test.local"

    send = await client.post(
        "/api/v1/auth/me/contact/send-codes",
        headers=headers,
        json={"email": email},
    )
    assert send.status_code == 200, send.text
    batch_id = send.json()["batch_id"]
    email_code = get_test_code("email", email)
    assert email_code is not None

    verified = await client.post(
        "/api/v1/auth/me/contact/verify-email",
        headers=headers,
        json={"batch_id": batch_id, "code": email_code},
    )
    assert verified.status_code == 200, verified.text

    request = await client.post(
        "/api/v1/auth/password-reset/request",
        json={"email": email},
    )
    assert request.status_code == 200, request.text
    reset_batch_id = request.json()["batch_id"]
    reset_code = get_test_code("email", email)
    assert reset_code is not None

    new_password = "ResetPass99"
    confirm = await client.post(
        "/api/v1/auth/password-reset/confirm",
        json={
            "batch_id": reset_batch_id,
            "code": reset_code,
            "new_password": new_password,
        },
    )
    assert confirm.status_code == 200, confirm.text

    login_ok = await client.post(
        "/api/v1/auth/login",
        json={"login": login, "password": new_password},
    )
    assert login_ok.status_code == 200, login_ok.text


@pytest.mark.asyncio
async def test_password_reset_invalid_code(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/password-reset/confirm",
        json={
            "batch_id": str(uuid.uuid4()),
            "code": "000000",
            "new_password": "ValidPass99",
        },
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_admin_reset_password(client: AsyncClient, admin_token: str) -> None:
    login, _ = await _register_user(client)
    headers = {"Authorization": f"Bearer {admin_token}"}
    users = (await client.get("/api/v1/users", headers=headers)).json()
    target = next(u for u in users if u["login"] == login)
    new_password = "AdminSetPass99"

    reset = await client.post(
        f"/api/v1/users/{target['id']}/reset-password",
        headers=headers,
        json={"new_password": new_password},
    )
    assert reset.status_code == 200, reset.text

    login_resp = await client.post(
        "/api/v1/auth/login",
        json={"login": login, "password": new_password},
    )
    assert login_resp.status_code == 200, login_resp.text
