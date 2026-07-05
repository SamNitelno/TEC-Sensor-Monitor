import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_websocket_rejects_missing_token(client: AsyncClient) -> None:
    with pytest.raises(Exception):
        async with client.websocket_connect("/ws") as _:
            pass


@pytest.mark.asyncio
async def test_websocket_accepts_valid_token(
    client: AsyncClient,
    admin_token: str,
) -> None:
    async with client.websocket_connect(f"/ws?token={admin_token}") as ws:
        await ws.send_text("ping")
