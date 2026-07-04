#!/usr/bin/env python3
"""Verify demo sensor readings exist."""

import asyncio
from datetime import UTC, datetime, timedelta

import httpx

BASE = "http://127.0.0.1:8000/api/v1"


async def main() -> None:
    async with httpx.AsyncClient(base_url=BASE, timeout=120, trust_env=False) as client:
        login = await client.post("/auth/login", json={"login": "admin", "password": "admin"})
        login.raise_for_status()
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

        seed = await client.post("/sensors/seed-demo-readings", headers=headers)
        print("seed status:", seed.status_code, seed.text[:500])

        sensors = await client.get("/sensors", headers=headers)
        sensors.raise_for_status()
        targets = [
            s for s in sensors.json()
            if s["name"] in {
                "Демо датчик 1",
                "Демо датчик 2",
                "Демо датчик 3",
                "Smoke Sensor",
            }
        ]
        print("target sensors:", [(s["id"], s["name"]) for s in targets])

        now = datetime.now(UTC)
        start = now - timedelta(hours=1)
        for sensor in targets:
            resp = await client.get(
                "/readings",
                headers=headers,
                params={
                    "from": start.isoformat(),
                    "to": now.isoformat(),
                    "sensor_ids": [sensor["id"]],
                    "bucket": "raw",
                },
            )
            count = sum(len(s["points"]) for s in resp.json().get("series", []))
            print(f"  {sensor['name']}: {count} points (last hour)")


if __name__ == "__main__":
    asyncio.run(main())
