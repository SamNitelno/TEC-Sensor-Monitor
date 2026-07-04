from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.downtime_event import DowntimeEvent, DowntimeType
from app.models.sensor import Sensor
from app.repositories import downtime_repository
from app.schemas.downtime import (
    DowntimeEventItem,
    DowntimeEventsResponse,
    DowntimeSummaryItem,
    DowntimeSummaryResponse,
    WorkshopDowntimeSummaryItem,
)


def _as_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _clip_seconds(
    event: DowntimeEvent,
    from_dt: datetime,
    to_dt: datetime,
    now: datetime,
) -> float:
    start = max(_as_utc(event.started_at), from_dt)
    end = min(_as_utc(event.ended_at) if event.ended_at else now, to_dt)
    if end <= start:
        return 0.0
    return (end - start).total_seconds()


def _to_event_item(event: DowntimeEvent) -> DowntimeEventItem:
    sensor = event.sensor
    site = sensor.site if sensor else None
    workshop = site.workshop if site else None
    return DowntimeEventItem(
        id=event.id,
        sensor_id=event.sensor_id,
        sensor_name=sensor.name if sensor else "",
        site_id=site.id if site else None,
        site_name=site.name if site else None,
        workshop_id=workshop.id if workshop else None,
        workshop_name=workshop.name if workshop else None,
        type=event.type.value,
        started_at=event.started_at,
        ended_at=event.ended_at,
        duration_seconds=(
            (event.ended_at - event.started_at).total_seconds()
            if event.ended_at is not None
            else None
        ),
    )


async def list_events(
    session: AsyncSession,
    *,
    from_dt: datetime,
    to_dt: datetime,
    sensor_id: int | None = None,
    site_id: int | None = None,
    workshop_id: int | None = None,
    event_type: DowntimeType | None = None,
) -> DowntimeEventsResponse:
    sensor_ids = [sensor_id] if sensor_id is not None else None
    events = await downtime_repository.list_events_in_range(
        session,
        from_dt=from_dt,
        to_dt=to_dt,
        sensor_ids=sensor_ids,
        site_id=site_id,
        workshop_id=workshop_id,
        event_type=event_type,
    )
    return DowntimeEventsResponse(
        events=[_to_event_item(event) for event in events],
    )


async def summarize(
    session: AsyncSession,
    *,
    from_dt: datetime,
    to_dt: datetime,
    sensor_id: int | None = None,
    site_id: int | None = None,
    workshop_id: int | None = None,
) -> DowntimeSummaryResponse:
    now = datetime.now(UTC)
    sensor_ids = [sensor_id] if sensor_id is not None else None
    sensors = await downtime_repository.list_sensors_for_scope(
        session,
        sensor_ids=sensor_ids,
        site_id=site_id,
        workshop_id=workshop_id,
    )
    events = await downtime_repository.list_events_in_range(
        session,
        from_dt=from_dt,
        to_dt=to_dt,
        sensor_ids=[sensor.id for sensor in sensors] or None,
        site_id=site_id,
        workshop_id=workshop_id,
    )

    per_sensor: dict[int, DowntimeSummaryItem] = {}
    for sensor in sensors:
        site = sensor.site
        workshop = site.workshop if site else None
        per_sensor[sensor.id] = DowntimeSummaryItem(
            sensor_id=sensor.id,
            sensor_name=sensor.name,
            site_id=site.id if site else None,
            site_name=site.name if site else None,
            workshop_id=workshop.id if workshop else None,
            workshop_name=workshop.name if workshop else None,
            offline_seconds=0.0,
            idle_seconds=0.0,
            total_seconds=0.0,
        )

    for event in events:
        item = per_sensor.get(event.sensor_id)
        if item is None:
            continue
        seconds = _clip_seconds(event, from_dt, to_dt, now)
        if event.type == DowntimeType.offline:
            item.offline_seconds += seconds
        else:
            item.idle_seconds += seconds
        item.total_seconds += seconds

    workshop_totals: dict[int, WorkshopDowntimeSummaryItem] = {}
    for item in per_sensor.values():
        if item.workshop_id is None:
            continue
        total = workshop_totals.get(item.workshop_id)
        if total is None:
            total = WorkshopDowntimeSummaryItem(
                workshop_id=item.workshop_id,
                workshop_name=item.workshop_name or "",
                offline_seconds=0.0,
                idle_seconds=0.0,
                total_seconds=0.0,
            )
            workshop_totals[item.workshop_id] = total
        total.offline_seconds += item.offline_seconds
        total.idle_seconds += item.idle_seconds
        total.total_seconds += item.total_seconds

    return DowntimeSummaryResponse(
        sensors=sorted(per_sensor.values(), key=lambda row: row.sensor_name),
        workshops=sorted(
            workshop_totals.values(),
            key=lambda row: row.workshop_name,
        ),
    )
