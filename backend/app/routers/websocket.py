from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict
import json

router = APIRouter(tags=["WebSocket"])

# Mapa de conexiones activas: {reserva_id: [websockets]}
active_connections: Dict[str, list] = {}


class ConnectionManager:
    def __init__(self):
        self.connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.connections:
            try:
                await connection.send_text(json.dumps(message))
            except Exception:
                pass


manager = ConnectionManager()


@router.websocket("/ws/timers")
async def websocket_timers(websocket: WebSocket):
    """WebSocket para timers en tiempo real. Admin conecta y recibe eventos de partidos."""
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Eco de ping para mantener la conexión viva
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(websocket)
