from collections.abc import Generator

import pytest
from starlette.testclient import TestClient

from app.db.session import get_db
from app.main import app
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.fixture
def ws_client(db_session: AsyncSession) -> Generator[TestClient, None, None]:
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


def test_websocket_rejects_missing_token(ws_client: TestClient) -> None:
    with pytest.raises(Exception):
        with ws_client.websocket_connect("/ws") as _:
            pass


def test_websocket_accepts_valid_token(ws_client: TestClient, admin_token: str) -> None:
    with ws_client.websocket_connect(f"/ws?token={admin_token}") as ws:
        ws.send_text("ping")
