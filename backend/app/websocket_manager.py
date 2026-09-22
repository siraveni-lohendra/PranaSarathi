from __future__ import annotations

from typing import Any

from fastapi import WebSocket

from .users import get_demo_user


class ConnectionManager:
    def __init__(self) -> None:
        self.active_connections: dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, user_id: str) -> None:
        await websocket.accept()
        self.active_connections[user_id] = websocket
        user = get_demo_user(user_id)
        if user is not None:
            user.websocket_connected = True

    def disconnect(self, user_id: str) -> None:
        self.active_connections.pop(user_id, None)
        user = get_demo_user(user_id)
        if user is not None:
            user.websocket_connected = False

    async def send_personal_message(self, user_id: str, message: dict[str, Any]) -> bool:
        websocket = self.active_connections.get(user_id)
        if websocket is None:
            return False
        await websocket.send_json(message)
        return True

    async def broadcast(self, message: dict[str, Any]) -> None:
        for websocket in list(self.active_connections.values()):
            await websocket.send_json(message)
