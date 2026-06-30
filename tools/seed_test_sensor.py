#!/usr/bin/env python3
"""Create a test site, workshop, and sensor for device/emulator development (idempotent)."""

import asyncio
import os
import secrets
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
os.chdir(REPO_ROOT)
sys.path.insert(0, str(REPO_ROOT / "backend"))

from sqlalchemy import select

from app.db.session import async_session_factory
from app.models.sensor import Sensor
from app.models.site import Site
from app.models.workshop import Workshop

TEST_SITE_NAME = "Тестовая площадка"
TEST_WORKSHOP_NAME = "Тестовый цех"
TEST_DEVICE_ID = "TEST-ESP-001"
TEST_SENSOR_NAME = "Тестовый датчик ESP"


async def seed_test_sensor() -> None:
    async with async_session_factory() as session:
        result = await session.execute(select(Sensor).where(Sensor.device_id == TEST_DEVICE_ID))
        existing = result.scalar_one_or_none()
        if existing is not None:
            print(f"device_id: {existing.device_id}")
            print(f"api_token: {existing.api_token}")
            return

        site_result = await session.execute(select(Site).where(Site.name == TEST_SITE_NAME))
        site = site_result.scalar_one_or_none()
        if site is None:
            site = Site(name=TEST_SITE_NAME)
            session.add(site)
            await session.flush()

        workshop_result = await session.execute(
            select(Workshop).where(
                Workshop.name == TEST_WORKSHOP_NAME,
                Workshop.site_id == site.id,
            )
        )
        workshop = workshop_result.scalar_one_or_none()
        if workshop is None:
            workshop = Workshop(name=TEST_WORKSHOP_NAME, site_id=site.id)
            session.add(workshop)
            await session.flush()

        api_token = secrets.token_urlsafe(32)
        sensor = Sensor(
            name=TEST_SENSOR_NAME,
            device_id=TEST_DEVICE_ID,
            api_token=api_token,
            workshop_id=workshop.id,
        )
        session.add(sensor)
        await session.commit()

        print(f"device_id: {TEST_DEVICE_ID}")
        print(f"api_token: {api_token}")


def main() -> None:
    asyncio.run(seed_test_sensor())


if __name__ == "__main__":
    main()
