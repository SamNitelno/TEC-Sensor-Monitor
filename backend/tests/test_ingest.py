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
