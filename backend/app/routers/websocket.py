from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select
from app.core.security import decode_token
from app.core.database import AsyncSessionLocal
from app.models.user import User
import json
import uuid as uuid_module

router = APIRouter(tags=["WebSocket"])


# ── Manager para admins (timers) ─────────────────────────────────────────────

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


# ── Manager para clientes (reservas/pagos en tiempo real) ────────────────────

class ClientConnectionManager:
    """Conexiones WS por usuario — un cliente puede tener un socket activo."""

    def __init__(self):
        self.connections: dict[str, WebSocket] = {}  # user_id (str) → websocket

    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        self.connections[user_id] = websocket

    def disconnect(self, user_id: str):
        self.connections.pop(user_id, None)

    async def notify(self, user_id: str | uuid_module.UUID, message: dict):
        """Envía un mensaje JSON al cliente si está conectado."""
        ws = self.connections.get(str(user_id))
        if ws:
            try:
                await ws.send_text(json.dumps(message))
            except Exception:
                self.connections.pop(str(user_id), None)


client_manager = ClientConnectionManager()


async def notify_cliente(user_id: str | uuid_module.UUID, message: dict):
    """Helper importable desde otros routers para notificar a un cliente vía WS."""
    await client_manager.notify(user_id, message)


# ── Endpoint: timers (admin / super_admin) ────────────────────────────────────

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


# ── Endpoint: cliente (reservas y pagos en tiempo real) ───────────────────────

@router.websocket("/ws/cliente")
async def websocket_cliente(websocket: WebSocket, token: str = ""):
    """WebSocket para clientes — reciben eventos cuando el admin aprueba/rechaza pagos."""
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

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(User).where(User.id == user_id, User.activo == True)
        )
        user = result.scalar_one_or_none()

    if not user or user.rol.value != "cliente":
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await client_manager.connect(user_id, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        client_manager.disconnect(user_id)
