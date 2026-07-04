import uuid

import pytest
from httpx import AsyncClient

from app.services.verification_delivery import get_test_code


@pytest.mark.asyncio
async def test_contact_verification_email_then_phone(client: AsyncClient, admin_token: str):
    headers = {"Authorization": f"Bearer {admin_token}"}
    suffix = uuid.uuid4().hex[:8]
    email = f"verify_{suffix}@test.local"
    phone = f"+79{int(suffix, 16) % 1000000000:09d}"

    send = await client.post(
        "/api/v1/auth/me/contact/send-codes",
        headers=headers,
        json={
            "email": email,
            "phone": phone,
        },
    )
    assert send.status_code == 200
    payload = send.json()
    assert payload["step"] == "email"
    batch_id = payload["batch_id"]

    email_code = get_test_code("email", email)
    assert email_code is not None

    verify_email = await client.post(
        "/api/v1/auth/me/contact/verify-email",
        headers=headers,
        json={"batch_id": batch_id, "code": email_code},
    )
    assert verify_email.status_code == 200
    assert verify_email.json()["step"] == "phone"

    phone_code = get_test_code("phone", phone)
    assert phone_code is not None

    verify_phone = await client.post(
        "/api/v1/auth/me/contact/verify-phone",
        headers=headers,
        json={"batch_id": batch_id, "code": phone_code},
    )
    assert verify_phone.status_code == 200
    assert verify_phone.json()["step"] == "complete"
    profile = verify_phone.json()["profile"]
    assert profile["email"] == email
    assert profile["phone"] == phone


@pytest.mark.asyncio
async def test_profile_update_login_only(client: AsyncClient, admin_token: str):
    headers = {"Authorization": f"Bearer {admin_token}"}
    me = await client.get("/api/v1/auth/me", headers=headers)
    original_login = me.json()["login"]

    updated = await client.post(
        "/api/v1/auth/me/contact/send-codes",
        headers=headers,
        json={"login": original_login},
    )
    assert updated.status_code == 200
    assert updated.json()["step"] == "complete"


@pytest.mark.asyncio
async def test_direct_email_patch_blocked(client: AsyncClient, admin_token: str):
    headers = {"Authorization": f"Bearer {admin_token}"}
    response = await client.patch(
        "/api/v1/auth/me",
        headers=headers,
        json={"email": "blocked@test.local"},
    )
    assert response.status_code == 400
