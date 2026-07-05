import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.reading import Reading
from app.models.sensor import Sensor, SensorStatus


@pytest.mark.asyncio
async def test_ingest_missing_token_returns_401(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/ingest",
        json={"current_a": 1.0},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_ingest_wrong_token_returns_401(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/ingest",
        headers={"X-Device-Token": "definitely-wrong-token"},
        json={"current_a": 1.0},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_ingest_valid_token_writes_and_updates_sensor(
    client: AsyncClient,
    db_session: AsyncSession,
    test_sensor_token: tuple[int, str],
) -> None:
    sensor_id, token = test_sensor_token

    before = await db_session.execute(
        select(func.count()).select_from(Reading).where(Reading.sensor_id == sensor_id)
    )
    count_before = before.scalar_one()

    response = await client.post(
        "/api/v1/ingest",
        headers={"X-Device-Token": token},
        json={"current_a": 7.77},
    )
    assert response.status_code == 202
    assert response.json() == {"accepted": 1}

    after = await db_session.execute(
        select(func.count()).select_from(Reading).where(Reading.sensor_id == sensor_id)
    )
    assert after.scalar_one() == count_before + 1

    sensor_result = await db_session.execute(select(Sensor).where(Sensor.id == sensor_id))
    sensor = sensor_result.scalar_one()
    assert sensor.status == SensorStatus.online
    assert sensor.last_seen is not None


@pytest.mark.asyncio
async def test_ingest_with_power_w_persisted(
    client: AsyncClient,
    db_session: AsyncSession,
    test_sensor_token: tuple[int, str],
) -> None:
    sensor_id, token = test_sensor_token
    response = await client.post(
        "/api/v1/ingest",
        headers={"X-Device-Token": token},
        json={"current_a": 9.1, "power_w": 2100.0},
    )
    assert response.status_code == 202

    row = await db_session.execute(
        select(Reading)
        .where(Reading.sensor_id == sensor_id)
        .order_by(Reading.time.desc())
        .limit(1)
    )
    reading = row.scalar_one()
    assert reading.current_a == pytest.approx(9.1)
    assert reading.power_w == pytest.approx(2100.0)


@pytest.mark.asyncio
async def test_ingest_without_power_w_still_works(
    client: AsyncClient,
    db_session: AsyncSession,
    test_sensor_token: tuple[int, str],
) -> None:
    sensor_id, token = test_sensor_token
    response = await client.post(
        "/api/v1/ingest",
        headers={"X-Device-Token": token},
        json={"current_a": 1.5},
    )
    assert response.status_code == 202

    row = await db_session.execute(
        select(Reading)
        .where(Reading.sensor_id == sensor_id)
        .order_by(Reading.time.desc())
        .limit(1)
    )
    reading = row.scalar_one()
    assert reading.current_a == pytest.approx(1.5)
    assert reading.power_w is None


@pytest.mark.asyncio
async def test_ingest_accepts_batch(
    client: AsyncClient,
    test_sensor_token: tuple[int, str],
) -> None:
    _, token = test_sensor_token
    response = await client.post(
        "/api/v1/ingest",
        headers={"X-Device-Token": token},
        json=[{"current_a": 1.1}, {"current_a": 2.2}],
    )
    assert response.status_code == 202
    assert response.json() == {"accepted": 2}


@pytest.mark.asyncio
async def test_ingest_duplicate_device_timestamp_updates_reading(
    client: AsyncClient,
    db_session: AsyncSession,
    test_sensor_token: tuple[int, str],
) -> None:
    from datetime import datetime

    from app.services.sensor_status import is_sensor_online

    sensor_id, token = test_sensor_token
    fixed_ts = "2026-06-01T12:00:00Z"

    for current in (1.0, 2.0):
        response = await client.post(
            "/api/v1/ingest",
            headers={"X-Device-Token": token},
            json={"current_a": current, "ts": fixed_ts},
        )
        assert response.status_code == 202

    row = await db_session.execute(
        select(Reading).where(
            Reading.sensor_id == sensor_id,
            Reading.time == datetime.fromisoformat("2026-06-01T12:00:00+00:00"),
        )
    )
    reading = row.scalar_one()
    assert reading.current_a == pytest.approx(2.0)

    sensor_result = await db_session.execute(select(Sensor).where(Sensor.id == sensor_id))
    sensor = sensor_result.scalar_one()
    assert is_sensor_online(sensor) is True


@pytest.mark.asyncio
async def test_ingest_rejects_out_of_range_current(
    client: AsyncClient,
    test_sensor_token: tuple[int, str],
) -> None:
    _, token = test_sensor_token
    response = await client.post(
        "/api/v1/ingest",
        headers={"X-Device-Token": token},
        json={"current_a": 99999.0},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_ingest_rejects_oversized_batch(
    client: AsyncClient,
    test_sensor_token: tuple[int, str],
) -> None:
    _, token = test_sensor_token
    batch = [{"current_a": 1.0} for _ in range(101)]
    response = await client.post(
        "/api/v1/ingest",
        headers={"X-Device-Token": token},
        json=batch,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_ingest_stale_device_timestamp_uses_server_time(
    client: AsyncClient,
    db_session: AsyncSession,
    test_sensor_token: tuple[int, str],
) -> None:
    from datetime import UTC, datetime

    sensor_id, token = test_sensor_token
    response = await client.post(
        "/api/v1/ingest",
        headers={"X-Device-Token": token},
        json={"current_a": 3.3, "ts": "1970-01-01T00:00:00Z"},
    )
    assert response.status_code == 202

    row = await db_session.execute(
        select(Reading)
        .where(Reading.sensor_id == sensor_id)
        .order_by(Reading.time.desc())
        .limit(1)
    )
    reading = row.scalar_one()
    assert reading.time >= datetime(2024, 1, 1, tzinfo=UTC)
