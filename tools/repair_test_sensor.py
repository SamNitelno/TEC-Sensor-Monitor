#!/usr/bin/env python3
"""Restore TEST-ESP-001 to the standard test workshop/site and remove test pollution."""

import asyncio
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
os.chdir(REPO_ROOT)
sys.path.insert(0, str(REPO_ROOT / "backend"))

from sqlalchemy import delete, select

from app.db.session import async_session_factory
from app.models.sensor import Sensor
from app.models.site import Site
from app.models.workshop import Workshop

TEST_WORKSHOP_NAME = "Тестовый цех"
TEST_SITE_NAME = "Тестовая площадка"
TEST_DEVICE_ID = "TEST-ESP-001"
POLLUTION_WORKSHOP_NAMES = ("W-notify-test",)
POLLUTION_SITE_NAMES = ("S-notify-test",)


async def repair() -> None:
    async with async_session_factory() as session:
        sensor_result = await session.execute(
            select(Sensor).where(Sensor.device_id == TEST_DEVICE_ID)
        )
        sensor = sensor_result.scalar_one_or_none()
        if sensor is None:
            print(f"Sensor {TEST_DEVICE_ID} not found")
            return

        workshop_result = await session.execute(
            select(Workshop).where(Workshop.name == TEST_WORKSHOP_NAME)
        )
        workshop = workshop_result.scalar_one_or_none()
        if workshop is None:
            workshop = Workshop(name=TEST_WORKSHOP_NAME, notifications_enabled=True)
            session.add(workshop)
            await session.flush()
            print(f"Created workshop: {TEST_WORKSHOP_NAME}")
        else:
            workshop.notifications_enabled = True

        site_result = await session.execute(
            select(Site).where(
                Site.name == TEST_SITE_NAME,
                Site.workshop_id == workshop.id,
            )
        )
        site = site_result.scalar_one_or_none()
        if site is None:
            site = Site(
                name=TEST_SITE_NAME,
                workshop_id=workshop.id,
                notifications_enabled=True,
            )
            session.add(site)
            await session.flush()
            print(f"Created site: {TEST_SITE_NAME}")
        else:
            site.notifications_enabled = True

        old_site_id = sensor.site_id
        sensor.site_id = site.id
        sensor.notifications_enabled = True
        print(
            f"Sensor {sensor.name}: site_id {old_site_id} -> {site.id}, notifications on"
        )

        for polluted_site_name in POLLUTION_SITE_NAMES:
            polluted_sites = await session.execute(
                select(Site).where(Site.name == polluted_site_name)
            )
            for polluted_site in polluted_sites.scalars().all():
                if polluted_site.id == site.id:
                    continue
                has_sensors = await session.execute(
                    select(Sensor.id).where(Sensor.site_id == polluted_site.id).limit(1)
                )
                if has_sensors.scalar_one_or_none() is not None:
                    print(f"Skip delete site {polluted_site_name!r}: still has sensors")
                    continue
                await session.delete(polluted_site)
                print(f"Deleted site: {polluted_site_name}")

        for polluted_workshop_name in POLLUTION_WORKSHOP_NAMES:
            polluted_workshops = await session.execute(
                select(Workshop).where(Workshop.name == polluted_workshop_name)
            )
            for polluted_workshop in polluted_workshops.scalars().all():
                if polluted_workshop.id == workshop.id:
                    continue
                remaining_sites = await session.execute(
                    select(Site.id).where(Site.workshop_id == polluted_workshop.id).limit(1)
                )
                if remaining_sites.scalar_one_or_none() is not None:
                    print(
                        f"Skip delete workshop {polluted_workshop_name!r}: still has sites"
                    )
                    continue
                await session.delete(polluted_workshop)
                print(f"Deleted workshop: {polluted_workshop_name}")

        await session.commit()
        print("Done.")


def main() -> None:
    asyncio.run(repair())


if __name__ == "__main__":
    main()
