from __future__ import annotations

import math

from .users import DemoUser, get_demo_user
from .websocket_manager import ConnectionManager


def haversine_meters(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float,
) -> float:
    radius = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return radius * c


async def notify_hospital_selection(
    manager: ConnectionManager,
    ambulance_id: str,
    hospital_id: str,
    hospital_name: str,
) -> dict:
    hospital = get_demo_user(hospital_id)
    ambulance = get_demo_user(ambulance_id)
    if hospital is None or ambulance is None:
        raise ValueError('Invalid ambulance or hospital user ID')

    message = {
        'type': 'hospital_notification',
        'ambulance_id': ambulance.user_id,
        'hospital_id': hospital.user_id,
        'title': 'Incoming Ambulance',
        'message': f'Ambulance {ambulance.user_id} selected your hospital.',
        'hospital_name': hospital_name,
        'hospital_display_name': hospital.name,
    }

    await manager.send_personal_message(hospital.user_id, message)
    return message


async def start_ambulance_emergency(
    manager: ConnectionManager,
    ambulance_id: str,
    radius_meters: int = 1000,
) -> dict:
    ambulance = get_demo_user(ambulance_id)
    if ambulance is None:
        raise ValueError('Invalid ambulance user ID')

    ambulance.emergency_active = True

    alerted_users: list[str] = []
    for user in get_demo_users().values():
        if user.role != 'road_user':
            continue
        distance = haversine_meters(
            ambulance.latitude,
            ambulance.longitude,
            user.latitude,
            user.longitude,
        )
        if distance <= radius_meters:
            message = {
                'type': 'ambulance_alert',
                'ambulance_id': ambulance.user_id,
                'distance_meters': int(distance),
                'title': 'Emergency Vehicle Approaching',
                'message': 'An ambulance is approaching nearby. Please give way.',
            }
            await manager.send_personal_message(user.user_id, message)
            alerted_users.append(user.user_id)

    return {
        'status': 'ok',
        'ambulance_id': ambulance.user_id,
        'emergency_active': ambulance.emergency_active,
        'alerted_users': alerted_users,
        'radius_meters': radius_meters,
    }


def get_demo_users():
    from .users import DEMO_USERS

    return DEMO_USERS
