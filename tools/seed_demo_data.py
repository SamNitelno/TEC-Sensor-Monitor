#!/usr/bin/env python3
"""Seed demo workshops, sites, sensors, and test users."""

import asyncio

import httpx

BASE = "http://localhost:8000/api/v1"


async def main() -> None:
    async with httpx.AsyncClient(base_url=BASE, timeout=120, trust_env=False) as client:
        login = await client.post("/auth/login", json={"login": "admin", "password": "admin"})
        login.raise_for_status()
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        for name, login_name, password in [
            ("operator1", "operator1", "Oper1234"),
            ("operator2", "operator2", "Oper1234"),
        ]:
            check = await client.get("/auth/check-login", params={"login": login_name})
            if check.json().get("available"):
                await client.post(
                    "/auth/register",
                    json={"login": login_name, "password": password},
                )

        workshops = []
        for name, color in [("Цех A", "#00D4AA"), ("Цех B", "#F5A623")]:
            ws = await client.post(
                "/workshops", headers=headers, json={"name": name, "color": color}
            )
            if ws.status_code == 201:
                workshops.append(ws.json())
            else:
                existing = await client.get("/workshops", headers=headers)
                workshops = existing.json()

        sites = []
        colors = ["#58A6FF", "#E06C75", "#D2A8FF"]
        idx = 0
        for ws in workshops:
            for n in range(1, 3):
                site_name = f"{ws['name']} · Площадка {n}"
                site = await client.post(
                    "/sites",
                    headers=headers,
                    json={
                        "name": site_name,
                        "workshop_id": ws["id"],
                        "color": colors[idx % len(colors)],
                    },
                )
                if site.status_code == 201:
                    sites.append(site.json())
                idx += 1

        if not sites:
            sites_resp = await client.get("/sites", headers=headers)
            sites = sites_resp.json()

        sensor_colors = ["#79C0FF", "#FF7B72", "#FFA657"]
        existing_sensors = (await client.get("/sensors", headers=headers)).json()
        existing_by_device = {s["device_id"]: s for s in existing_sensors}
        existing_by_name = {s["name"]: s for s in existing_sensors}

        for i, site in enumerate(sites[:3]):
            device_id = f"DEMO-SENSOR-{i + 1:03d}"
            name = f"Демо датчик {i + 1}"
            if device_id in existing_by_device or name in existing_by_name:
                continue
            await client.post(
                "/sensors",
                headers=headers,
                json={
                    "name": name,
                    "device_id": device_id,
                    "site_id": site["id"],
                    "color": sensor_colors[i % len(sensor_colors)],
                },
            )

        if "Smoke Sensor" not in existing_by_name and sites:
            smoke_device = "SMOKE-DEMO-001"
            if smoke_device not in existing_by_device:
                await client.post(
                    "/sensors",
                    headers=headers,
                    json={
                        "name": "Smoke Sensor",
                        "device_id": smoke_device,
                        "site_id": sites[0]["id"],
                        "color": "#D2A8FF",
                    },
                )

        print("Demo sensors ensured")

        readings = await client.post("/sensors/seed-demo-readings", headers=headers, timeout=120)
        if readings.status_code == 200:
            print(f"Demo readings: {readings.json()}")
        else:
            print(f"Demo readings failed: {readings.status_code} {readings.text}")


if __name__ == "__main__":
    asyncio.run(main())
