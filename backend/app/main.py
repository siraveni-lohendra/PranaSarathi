from __future__ import annotations

from typing import Any

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field

from .emergency_service import notify_hospital_selection, start_ambulance_emergency
from .users import DEMO_USERS, get_demo_users
from .websocket_manager import ConnectionManager

app = FastAPI(title='PranaSarathi Backend')
manager = ConnectionManager()


class UserLocationUpdate(BaseModel):
    user_id: str = Field(..., min_length=1)
    latitude: float
    longitude: float


class HospitalSelectionRequest(BaseModel):
    ambulance_id: str = Field(..., min_length=1)
    hospital_id: str = Field(..., min_length=1)
    hospital_name: str = Field(default='Selected Hospital')


@app.get('/api/v1/health')
async def health() -> dict[str, str]:
    return {'status': 'ok'}


@app.get('/api/v1/users')
async def get_users() -> list[dict[str, Any]]:
    return [user.to_dict() for user in get_demo_users()]


@app.post('/api/v1/location')
async def update_location(payload: UserLocationUpdate) -> dict[str, Any]:
    user = DEMO_USERS.get(payload.user_id)
    if user is None:
        raise HTTPException(status_code=404, detail='User not found')

    user.latitude = payload.latitude
    user.longitude = payload.longitude
    return {
        'status': 'ok',
        'user_id': user.user_id,
        'latitude': user.latitude,
        'longitude': user.longitude,
    }


@app.post('/api/v1/emergency/select-hospital')
async def select_hospital(payload: HospitalSelectionRequest) -> dict[str, Any]:
    try:
        message = await notify_hospital_selection(
            manager,
            payload.ambulance_id,
            payload.hospital_id,
            payload.hospital_name,
        )
        return {
            'status': 'ok',
            'message': 'Hospital notification sent',
            'payload': message,
        }
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post('/api/v1/emergency/start/{ambulance_id}')
async def start_emergency(ambulance_id: str) -> dict[str, Any]:
    try:
        result = await start_ambulance_emergency(manager, ambulance_id)
        return result
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.websocket('/ws/{user_id}')
async def websocket_endpoint(websocket: WebSocket, user_id: str) -> None:
    user = DEMO_USERS.get(user_id)
    if user is None:
        await websocket.close(code=1008)
        return

    await manager.connect(websocket, user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_id)
