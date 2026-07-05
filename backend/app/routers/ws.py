import asyncio

import jwt
import structlog
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select

from app.core.security import decode_access_token
from app.db.session import async_session_factory
from app.models.user import User
from app.services.ws_manager import ws_manager

logger = structlog.get_logger(__name__)

router = APIRouter(tags=["websocket"])


async def _validate_ws_user(token: str) -> bool:
    try:
        payload = decode_access_token(token)
    except jwt.PyJWTError:
        return False

    user_id = payload.get("uid")
    login = payload.get("sub")
    if user_id is None and not login:
        return False

    async with async_session_factory() as session:
        if user_id is not None:
            result = await session.execute(select(User).where(User.id == user_id))
        else:
            result = await session.execute(select(User).where(User.login == login))
        user = result.scalar_one_or_none()
        return user is not None and user.is_active


@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str | None = Query(default=None),
) -> None:
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    if not await _validate_ws_user(token):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await ws_manager.connect(websocket)
    logger.info("ws_client_connected")

    try:
        while True:
            try:
                await asyncio.wait_for(websocket.receive_text(), timeout=60.0)
            except TimeoutError:
                await websocket.send_json({"type": "ping"})
    except WebSocketDisconnect:
        pass
    finally:
        await ws_manager.disconnect(websocket)
        logger.info("ws_client_disconnected")
