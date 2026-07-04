"""Downtime detection: offline and idle events."""

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import delete, select

from app.models.downtime_event import DowntimeEvent, DowntimeType
from app.models.reading import Reading
from app.models.sensor import SensorStatus
from app.repositories import downtime_repository, reading_repository, sensor_repository
from app.services import downtime_service
from app.services.downtime_detection_service import (
    _idle_pending_since,
    run_downtime_detection_cycle,
)
from app.services.ingest_service import ingest_readings
from app.schemas.ingest import ReadingIn


@pytest.fixture(autouse=True)
async def _reset_downtime_tables(db_session, test_sensor_token):
    sensor_id, _token = test_sensor_token
    _idle_pending_since.clear()
    await db_session.execute(
        delete(DowntimeEvent).where(DowntimeEvent.sensor_id == sensor_id)
    )
    await db_session.execute(delete(Reading).where(Reading.sensor_id == sensor_id))
    await db_session.commit()
    yield
    _idle_pending_since.clear()


@pytest.mark.asyncio
async def test_offline_event_opened_when_stale(db_session, test_sensor_token):
    sensor_id, _token = test_sensor_token
    _idle_pending_since.clear()

    now = datetime.now(UTC)
    await reading_repository.bulk_insert_readings(
        db_session,
        [(now - timedelta(seconds=30), sensor_id, 5.0, 1000.0)],
    )
    await sensor_repository.update_last_seen(db_session, sensor_id, now - timedelta(seconds=30))
    await db_session.commit()

    await run_downtime_detection_cycle(db_session)

    sensor = await sensor_repository.get_by_id(db_session, sensor_id)
    assert sensor is not None
    assert sensor.status == SensorStatus.offline

    event = await downtime_repository.get_open_event(
        db_session, sensor_id, DowntimeType.offline
    )
    assert event is not None
    assert event.ended_at is None


@pytest.mark.asyncio
async def test_offline_event_closed_on_ingest_resume(db_session, test_sensor_token):
    sensor_id, _token = test_sensor_token
    _idle_pending_since.clear()

    stale = datetime.now(UTC) - timedelta(seconds=30)
    await reading_repository.bulk_insert_readings(
        db_session,
        [(stale, sensor_id, 5.0, 1000.0)],
    )
    await sensor_repository.update_last_seen(db_session, sensor_id, stale)
    await downtime_repository.create_event(
        db_session,
        sensor_id=sensor_id,
        event_type=DowntimeType.offline,
        started_at=stale,
    )
    await db_session.commit()

    sensor = await sensor_repository.get_by_id(db_session, sensor_id)
    assert sensor is not None
    await ingest_readings(
        db_session,
        sensor,
        [ReadingIn(current_a=4.0, power_w=900.0)],
    )

    event = await downtime_repository.get_open_event(
        db_session, sensor_id, DowntimeType.offline
    )
    assert event is None

    result = await db_session.execute(
        select(DowntimeEvent).where(
            DowntimeEvent.sensor_id == sensor_id,
            DowntimeEvent.type == DowntimeType.offline,
        )
    )
    closed = result.scalar_one()
    assert closed.ended_at is not None


@pytest.mark.asyncio
async def test_idle_event_on_low_power(db_session, test_sensor_token):
    sensor_id, _token = test_sensor_token
    _idle_pending_since.clear()

    now = datetime.now(UTC)
    sensor = await sensor_repository.get_by_id(db_session, sensor_id)
    assert sensor is not None
    await sensor_repository.update(
        db_session,
        sensor,
        idle_power_threshold_w=100.0,
        idle_duration_seconds=0,
    )
    await db_session.commit()

    for offset in range(6):
        await reading_repository.bulk_insert_readings(
            db_session,
            [
                (
                    now - timedelta(seconds=30 - offset * 5),
                    sensor_id,
                    0.1,
                    10.0,
                )
            ],
        )
    await sensor_repository.update_last_seen(db_session, sensor_id, now)
    await db_session.commit()

    _idle_pending_since[sensor_id] = now - timedelta(seconds=120)
    await run_downtime_detection_cycle(db_session)

    event = await downtime_repository.get_open_event(
        db_session, sensor_id, DowntimeType.idle
    )
    assert event is not None
    assert event.ended_at is None


@pytest.mark.asyncio
async def test_idle_closed_when_current_high_but_power_low(
    db_session,
    test_sensor_token,
):
    """power_w=0 with load current must not keep sensor idle."""
    sensor_id, _token = test_sensor_token
    _idle_pending_since.clear()

    now = datetime.now(UTC)
    await downtime_repository.create_event(
        db_session,
        sensor_id=sensor_id,
        event_type=DowntimeType.idle,
        started_at=now - timedelta(minutes=5),
    )
    await db_session.commit()

    sensor = await sensor_repository.get_by_id(db_session, sensor_id)
    assert sensor is not None
    await ingest_readings(
        db_session,
        sensor,
        [ReadingIn(current_a=4.2, power_w=0.0)],
    )

    event = await downtime_repository.get_open_event(
        db_session, sensor_id, DowntimeType.idle
    )
    assert event is None


@pytest.mark.asyncio
async def test_idle_closed_on_ingest_activity(db_session, test_sensor_token):
    sensor_id, _token = test_sensor_token
    _idle_pending_since.clear()

    now = datetime.now(UTC)
    await downtime_repository.create_event(
        db_session,
        sensor_id=sensor_id,
        event_type=DowntimeType.idle,
        started_at=now - timedelta(minutes=5),
    )
    await db_session.commit()

    sensor = await sensor_repository.get_by_id(db_session, sensor_id)
    assert sensor is not None
    await ingest_readings(
        db_session,
        sensor,
        [ReadingIn(current_a=8.0, power_w=1500.0)],
    )

    event = await downtime_repository.get_open_event(
        db_session, sensor_id, DowntimeType.idle
    )
    assert event is None


@pytest.mark.asyncio
async def test_idle_event_closed_when_power_rises(db_session, test_sensor_token):
    sensor_id, _token = test_sensor_token
    _idle_pending_since.clear()

    now = datetime.now(UTC)
    sensor = await sensor_repository.get_by_id(db_session, sensor_id)
    assert sensor is not None
    await sensor_repository.update(
        db_session,
        sensor,
        idle_power_threshold_w=100.0,
        idle_duration_seconds=0,
    )
    await downtime_repository.create_event(
        db_session,
        sensor_id=sensor_id,
        event_type=DowntimeType.idle,
        started_at=now - timedelta(minutes=5),
    )
    await reading_repository.bulk_insert_readings(
        db_session,
        [
            (now - timedelta(seconds=offset), sensor_id, 8.0, 1500.0)
            for offset in range(5, 0, -1)
        ],
    )
    await sensor_repository.update_last_seen(db_session, sensor_id, now)
    await db_session.commit()

    await run_downtime_detection_cycle(db_session)

    event = await downtime_repository.get_open_event(
        db_session, sensor_id, DowntimeType.idle
    )
    assert event is None


@pytest.mark.asyncio
async def test_downtime_summary_matches_interval(
    db_session,
    test_sensor_token,
):
    sensor_id, _token = test_sensor_token
    now = datetime.now(UTC)
    started = now - timedelta(hours=2)
    ended = now - timedelta(hours=1)
    await downtime_repository.create_event(
        db_session,
        sensor_id=sensor_id,
        event_type=DowntimeType.idle,
        started_at=started,
    )
    event = await downtime_repository.get_open_event(
        db_session, sensor_id, DowntimeType.idle
    )
    assert event is not None
    await downtime_repository.close_event(db_session, event, ended)
    await db_session.commit()

    summary = await downtime_service.summarize(
        db_session,
        from_dt=now - timedelta(hours=3),
        to_dt=now,
        sensor_id=sensor_id,
    )
    row = next(item for item in summary.sensors if item.sensor_id == sensor_id)
    assert row.idle_seconds == pytest.approx(3600.0, rel=0.01)


@pytest.mark.asyncio
async def test_downtime_events_api(
    client,
    viewer_token,
    db_session,
    test_sensor_token,
):
    sensor_id, _token = test_sensor_token
    now = datetime.now(UTC)
    await downtime_repository.create_event(
        db_session,
        sensor_id=sensor_id,
        event_type=DowntimeType.offline,
        started_at=now - timedelta(minutes=10),
    )
    await db_session.commit()

    response = await client.get(
        "/api/v1/downtime/events",
        params={
            "from": (now - timedelta(hours=1)).isoformat(),
            "to": now.isoformat(),
            "sensor_id": sensor_id,
        },
        headers={"Authorization": f"Bearer {viewer_token}"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert len(payload["events"]) >= 1
    assert payload["events"][0]["type"] == "offline"
