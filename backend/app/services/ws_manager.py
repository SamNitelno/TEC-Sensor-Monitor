import asyncio
import json
from datetime import datetime
from typing import Any

from fastapi import WebSocket
from starlette.websockets import WebSocketState

from app.models.sensor import SensorStatus


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections.add(websocket)

    async def disconnect(self, websocket: WebSocket) -> None:
        async with self._lock:
            self._connections.discard(websocket)

    async def broadcast(self, message: dict[str, Any]) -> None:
        payload = json.dumps(message, default=_json_default)
        async with self._lock:
            dead: list[WebSocket] = []
            for websocket in self._connections:
                if websocket.client_state != WebSocketState.CONNECTED:
                    dead.append(websocket)
                    continue
                try:
                    await websocket.send_text(payload)
                except Exception:
                    dead.append(websocket)
            for websocket in dead:
                self._connections.discard(websocket)

    async def broadcast_reading(
        self,
        *,
        sensor_id: int,
        current_a: float,
        power_w: float | None,
        ts: datetime,
    ) -> None:
        await self.broadcast(
            {
                "type": "reading",
                "sensor_id": sensor_id,
                "current_a": current_a,
                "power_w": power_w,
                "ts": ts,
            }
        )

    async def broadcast_sensor_status(
        self,
        *,
        sensor_id: int,
        status: SensorStatus,
        last_seen: datetime | None = None,
    ) -> None:
        await self.broadcast(
            {
                "type": "sensor_status",
                "sensor_id": sensor_id,
                "status": status.value,
                "last_seen": last_seen,
            }
        )


def _json_default(value: Any) -> str:
    if isinstance(value, datetime):
        return value.isoformat()
    raise TypeError(f"Object of type {type(value)} is not JSON serializable")


ws_manager = ConnectionManager()
