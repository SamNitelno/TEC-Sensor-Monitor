#!/usr/bin/env python3
"""Quick API smoke tests for users/auth/colors."""

import asyncio
import sys
import time

import httpx

BASE = "http://127.0.0.1:8000/api/v1"


async def main() -> int:
    login = f"smoke_user_{int(time.time())}"
    async with httpx.AsyncClient(base_url=BASE, timeout=15, trust_env=False) as client:
        check = await client.get("/auth/check-login", params={"login": login})
        assert check.status_code == 200, check.text
        assert check.json()["available"] is True

        reg = await client.post(
            "/auth/register",
            json={"login": login, "password": "Pass1234"},
        )
        assert reg.status_code == 201, reg.text
        assert reg.json()["role"] == "viewer"

        bad = await client.post(
            "/auth/register",
            json={"login": login, "password": "12345678"},
        )
        assert bad.status_code in (400, 422), bad.text

        login_resp = await client.post("/auth/login", json={"login": "admin", "password": "admin"})
        assert login_resp.status_code == 200, login_resp.text
        token = login_resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        me = await client.get("/auth/me", headers=headers)
        assert me.status_code == 200, me.text

        users = await client.get("/users", headers=headers)
        assert users.status_code == 200, users.text
        smoke = next(u for u in users.json() if u["login"] == login)

        promote = await client.post(f"/users/{smoke['id']}/promote", headers=headers)
        assert promote.status_code == 200, promote.text

        demote = await client.post(f"/users/{smoke['id']}/demote", headers=headers)
        assert demote.status_code == 200, demote.text

        ws = await client.post(
            "/workshops",
            headers=headers,
            json={"name": "Smoke WS", "color": "#AABBCC"},
        )
        assert ws.status_code == 201, ws.text
        ws_id = ws.json()["id"]

        site = await client.post(
            "/sites",
            headers=headers,
            json={"name": "Smoke Site", "workshop_id": ws_id, "color": "#112233"},
        )
        assert site.status_code == 201, site.text
        site_id = site.json()["id"]

        sensor = await client.post(
            "/sensors",
            headers=headers,
            json={
                "name": "Smoke Sensor",
                "device_id": f"SMOKE-{int(time.time())}",
                "site_id": site_id,
                "color": "#445566",
            },
        )
        assert sensor.status_code == 201, sensor.text
        sensor_id = sensor.json()["sensor"]["id"]

        audit = await client.get(f"/sensors/{sensor_id}/audit", headers=headers)
        assert audit.status_code == 200, audit.text
        assert audit.json()["created_by_login"] == "admin"

        print("All smoke tests passed")
        return 0


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(main()))
    except Exception as exc:
        print(f"FAILED: {exc!r}", file=sys.stderr)
        raise SystemExit(1) from exc
