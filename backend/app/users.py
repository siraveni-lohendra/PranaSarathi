from __future__ import annotations

from dataclasses import dataclass


@dataclass
class DemoUser:
    user_id: str
    name: str
    role: str
    latitude: float = 0.0
    longitude: float = 0.0
    websocket_connected: bool = False
    emergency_active: bool = False

    def to_dict(self) -> dict:
        return {
            'user_id': self.user_id,
            'name': self.name,
            'role': self.role,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'websocket_connected': self.websocket_connected,
            'emergency_active': self.emergency_active,
        }


DEMO_USERS: dict[str, DemoUser] = {
    'AMB001': DemoUser(
        user_id='AMB001',
        name='Demo Ambulance',
        role='ambulance',
        latitude=17.3850,
        longitude=78.4867,
    ),
    'HOS001': DemoUser(
        user_id='HOS001',
        name='Demo Hospital',
        role='hospital',
        latitude=17.3920,
        longitude=78.4900,
    ),
    'ROAD001': DemoUser(
        user_id='ROAD001',
        name='Demo Road User',
        role='road_user',
        latitude=17.3900,
        longitude=78.4850,
    ),
}


def get_demo_user(user_id: str | None) -> DemoUser | None:
    if user_id is None:
        return None
    return DEMO_USERS.get(user_id)


def get_demo_users() -> list[DemoUser]:
    return list(DEMO_USERS.values())
