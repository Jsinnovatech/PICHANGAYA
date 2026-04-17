"""
fcm.py — Envío de push notifications via Firebase Cloud Messaging HTTP v1 API.
Usa la cuenta de servicio JSON para autenticarse (no la legacy Server Key).
"""
import json
import logging
import os
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

_FCM_ENDPOINT = "https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
_TOKEN_URL = "https://oauth2.googleapis.com/token"
_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

# Cache del access token en memoria (se rota cada ~60 min)
_cached_token: Optional[str] = None
_token_expires_at: float = 0.0


async def _get_access_token(service_account_path: str) -> Optional[str]:
    """Obtiene un access token OAuth2 desde la cuenta de servicio."""
    global _cached_token, _token_expires_at
    import time

    if _cached_token and time.time() < _token_expires_at - 60:
        return _cached_token

    try:
        with open(service_account_path) as f:
            sa = json.load(f)

        import jwt as pyjwt  # PyJWT
        now = int(time.time())
        payload = {
            "iss": sa["client_email"],
            "sub": sa["client_email"],
            "aud": _TOKEN_URL,
            "iat": now,
            "exp": now + 3600,
            "scope": _SCOPE,
        }
        assertion = pyjwt.encode(payload, sa["private_key"], algorithm="RS256")

        async with httpx.AsyncClient() as client:
            res = await client.post(
                _TOKEN_URL,
                data={
                    "grant_type": "urn:ietf:params:oauth2:grant-type:jwt-bearer",
                    "assertion": assertion,
                },
                timeout=10.0,
            )

        if res.status_code == 200:
            data = res.json()
            _cached_token = data["access_token"]
            _token_expires_at = time.time() + data.get("expires_in", 3600)
            return _cached_token

        logger.warning(f"FCM token error: {res.text}")
        return None

    except Exception as e:
        logger.warning(f"FCM _get_access_token error: {e}")
        return None


async def send_push(
    fcm_token: str,
    titulo: str,
    cuerpo: str,
    data: Optional[dict] = None,
) -> bool:
    """
    Envía una push notification a un dispositivo via FCM HTTP v1.
    Retorna True si se envió correctamente, False si falló.
    """
    from app.core.config import settings

    sa_path = settings.FIREBASE_SERVICE_ACCOUNT_JSON
    if not os.path.exists(sa_path):
        logger.warning(f"FCM: archivo de cuenta de servicio no encontrado: {sa_path}")
        return False

    try:
        with open(sa_path) as f:
            sa = json.load(f)
        project_id = sa.get("project_id")
        if not project_id:
            logger.warning("FCM: project_id no encontrado en service account")
            return False
    except Exception as e:
        logger.warning(f"FCM: error leyendo service account: {e}")
        return False

    access_token = await _get_access_token(sa_path)
    if not access_token:
        return False

    message: dict = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": titulo,
                "body": cuerpo,
            },
            "android": {
                "priority": "high",
                "notification": {
                    "channel_id": "pichangaya_alta_prioridad",
                    "sound": "default",
                },
            },
        }
    }
    if data:
        # FCM solo acepta strings en data
        message["message"]["data"] = {k: str(v) for k, v in data.items()}

    endpoint = _FCM_ENDPOINT.format(project_id=project_id)
    try:
        async with httpx.AsyncClient() as client:
            res = await client.post(
                endpoint,
                json=message,
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                },
                timeout=10.0,
            )
        if res.status_code == 200:
            return True
        logger.warning(f"FCM send error {res.status_code}: {res.text}")
        return False
    except Exception as e:
        logger.warning(f"FCM send exception: {e}")
        return False
