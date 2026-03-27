from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
import uuid

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.notificacion import Notificacion
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

router = APIRouter(prefix="/notificaciones", tags=["Notificaciones"])


class NotificacionResponse(BaseModel):
    id: uuid.UUID
    tipo: str
    titulo: str
    mensaje: str
    leida: bool
    data: Optional[dict] = None
    created_at: Optional[str] = None

    class Config:
        from_attributes = True


@router.get("/", response_model=List[NotificacionResponse])
async def mis_notificaciones(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Devuelve las notificaciones del usuario autenticado.
    Flutter hace polling cada 30 segundos para mostrar el badge.
    """
    result = await db.execute(
        select(Notificacion)
        .where(Notificacion.usuario_id == uuid.UUID(current_user["id"]))
        .order_by(Notificacion.created_at.desc())
        .limit(50)
        # Últimas 50 notificaciones
    )
    notificaciones = result.scalars().all()

    return [
        NotificacionResponse(
            id=n.id,
            tipo=n.tipo.value,
            titulo=n.titulo,
            mensaje=n.mensaje,
            leida=n.leida,
            data=n.data,
            created_at=str(n.created_at) if n.created_at else None
        )
        for n in notificaciones
    ]


@router.get("/no-leidas")
async def contar_no_leidas(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Devuelve el conteo de notificaciones no leídas.
    Flutter usa esto para mostrar el badge rojo en el ícono.
    """
    from sqlalchemy import func
    result = await db.execute(
        select(func.count(Notificacion.id))
        .where(
            Notificacion.usuario_id == uuid.UUID(current_user["id"]),
            Notificacion.leida == False
        )
    )
    total = result.scalar() or 0
    return {"no_leidas": total}


@router.patch("/{notificacion_id}/leer")
async def marcar_leida(
    notificacion_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Marca una notificación como leída.
    Flutter llama esto cuando el usuario toca la notificación.
    """
    result = await db.execute(
        select(Notificacion).where(
            Notificacion.id == notificacion_id,
            Notificacion.usuario_id == uuid.UUID(current_user["id"])
        )
    )
    notif = result.scalar_one_or_none()

    if not notif:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Notificación no encontrada")

    notif.leida = True
    await db.commit()
    return {"mensaje": "Notificación marcada como leída"}


@router.patch("/leer-todas")
async def marcar_todas_leidas(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Marca todas las notificaciones del usuario como leídas.
    Flutter llama esto cuando el usuario abre el panel de notificaciones.
    """
    from sqlalchemy import update
    await db.execute(
        update(Notificacion)
        .where(
            Notificacion.usuario_id == uuid.UUID(current_user["id"]),
            Notificacion.leida == False
        )
        .values(leida=True)
    )
    await db.commit()
    return {"mensaje": "Todas las notificaciones marcadas como leídas"}