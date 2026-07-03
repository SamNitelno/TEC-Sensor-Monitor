import asyncio
import logging
from datetime import UTC, datetime, timedelta

from app.core.config import settings
from app.db.session import async_session_factory
from app.repositories import sensor_repository

logger = logging.getLogger(__name__)


async def mark_stale_sensors_offline() -> int:
    threshold = datetime.now(UTC) - timedelta(seconds=settings.sensor_offline_threshold_seconds)
    async with async_session_factory() as session:
        count = await sensor_repository.mark_stale_offline(session, older_than=threshold)
        await session.commit()
        return count


async def offline_watchdog_loop() -> None:
    while True:
        try:
            count = await mark_stale_sensors_offline()
            if count:
                logger.info("Marked %s sensor(s) offline (no telemetry)", count)
        except Exception:
            logger.exception("Offline watchdog failed")
        await asyncio.sleep(settings.sensor_offline_check_interval_seconds)
