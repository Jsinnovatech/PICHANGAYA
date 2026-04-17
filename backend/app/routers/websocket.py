from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select
from app.core.security import decode_token
from app.core.database import AsyncSessionLocal
from app.models.user import User
import json

router = APIRouter(tags=["WebSocket"])


class ConnectionManager:
    def __init__(self):
        self.connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.connections:
            self.connections.remove(websocket)

    async def broadcast(self, message: dict):
        dead = []
        for connection in self.connections:
            try:
                await connection.send_text(json.dumps(message))
            except Exception:
                dead.append(connection)
        for c in dead:
            self.connections.remove(c)


manager = ConnectionManager()


@router.websocket("/ws/timers")
async def websocket_timers(websocket: WebSocket, token: str = ""):
    """WebSocket para timers en tiempo real. Requiere token JWT válido como query param."""
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    payload = decode_token(token)
    if payload is None or payload.get("type") != "access":
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    user_id = payload.get("sub")
    if not user_id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Verificar rol desde BD — no confiar en el JWT
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(User).where(User.id == user_id, User.activo == True)
        )
        user = result.scalar_one_or_none()

    if not user or user.rol.value not in ("admin", "super_admin"):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(websocket)
