from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient

from app.repositories.readings_query_repository import MAX_POINTS, auto_select_bucket


def test_auto_select_bucket_year_uses_day() -> None:
    from_dt = datetime(2025, 1, 1, tzinfo=UTC)
    to_dt = datetime(2026, 1, 1, tzinfo=UTC)
    assert auto_select_bucket(from_dt, to_dt).value == "day"


def test_auto_select_bucket_short_range_uses_raw() -> None:
    from_dt = datetime.now(UTC) - timedelta(hours=1)
    to_dt = datetime.now(UTC)
    assert auto_select_bucket(from_dt, to_dt).value == "raw"


@pytest.mark.asyncio
async def test_readings_year_range_under_limit(
    client: AsyncClient,
    admin_token: str,
    test_sensor_token: tuple[int, str],
) -> None:
    sensor_id, _ = test_sensor_token
    headers = {"Authorization": f"Bearer {admin_token}"}
    from_dt = "2025-06-30T00:00:00Z"
    to_dt = "2026-06-30T23:59:59Z"
    response = await client.get(
        f"/api/v1/sensors/{sensor_id}/readings",
        headers=headers,
        params={"from": from_dt, "to": to_dt},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["bucket"] == "day"
    assert len(body["points"]) < MAX_POINTS
