from datetime import UTC, datetime

from app.core.config import settings
from app.models.sensor import Sensor, SensorStatus


def _as_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def is_sensor_online(sensor: Sensor, *, now: datetime | None = None) -> bool:
    if sensor.last_seen is None:
        return False
    moment = now or datetime.now(UTC)
    age = (moment - _as_utc(sensor.last_seen)).total_seconds()
    return age <= settings.sensor_offline_threshold_seconds


def effective_status(sensor: Sensor, *, now: datetime | None = None) -> SensorStatus:
    return SensorStatus.online if is_sensor_online(sensor, now=now) else SensorStatus.offline
