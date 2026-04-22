"""CRUD de horarios disponibles por cancha — solo admin."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
from datetime import time as time_type
import uuid

from app.core.database import get_db
from app.core.dependencies import require_admin
from app.models.horario import HorarioDisponible
from app.models.cancha import Cancha
from app.models.local import Local
from pydantic import BaseModel

router = APIRouter(prefix="/admin/horarios", tags=["Horarios"])


# ── Schemas inline ────────────────────────────────────────────

class HorarioCreate(BaseModel):
    cancha_id: uuid.UUID
    dia_semana: int          # 0=Lun … 6=Dom
    hora_inicio: str         # "HH:MM"
    hora_fin: str            # "HH:MM"
    precio_override: Optional[float] = None
    activo: bool = True


class HorarioUpdate(BaseModel):
    dia_semana: Optional[int] = None
    hora_inicio: Optional[str] = None
    hora_fin: Optional[str] = None
    precio_override: Optional[float] = None
    activo: Optional[bool] = None


class HorarioResponse(BaseModel):
    id: uuid.UUID
    cancha_id: uuid.UUID
    dia_semana: int
    hora_inicio: str
    hora_fin: str
    precio_override: Optional[float]
    activo: bool

    class Config:
        from_attributes = True


# ── Helper ────────────────────────────────────────────────────

def _parse_time(hora_str: str) -> time_type:
    try:
        h, m = hora_str.split(":")[:2]
        return time_type(int(h), int(m))
    except (ValueError, IndexError):
        raise HTTPException(status_code=400, detail=f"Hora inválida: '{hora_str}'. Use HH:MM")


async def _verificar_pertenencia(cancha_id: uuid.UUID, admin_id: str, db: AsyncSession):
    """Verifica que la cancha pertenezca a un local del admin autenticado."""
    result = await db.execute(
        select(Cancha).where(Cancha.id == cancha_id)
    )
    cancha = result.scalar_one_or_none()
    if not cancha:
        raise HTTPException(status_code=404, detail="Cancha no encontrada")

    local_result = await db.execute(
        select(Local).where(Local.id == cancha.local_id, Local.admin_id == uuid.UUID(admin_id))
    )
    if not local_result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="No tienes permiso sobre esta cancha")

    return cancha


# ── Endpoints ─────────────────────────────────────────────────

@router.get("/cancha/{cancha_id}", response_model=List[HorarioResponse])
async def listar_horarios(
    cancha_id: uuid.UUID,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    await _verificar_pertenencia(cancha_id, current_user["id"], db)
    result = await db.execute(
        select(HorarioDisponible)
        .where(HorarioDisponible.cancha_id == cancha_id)
        .order_by(HorarioDisponible.dia_semana, HorarioDisponible.hora_inicio)
    )
    horarios = result.scalars().all()
    return [HorarioResponse(
        id=h.id,
        cancha_id=h.cancha_id,
        dia_semana=h.dia_semana,
        hora_inicio=str(h.hora_inicio)[:5],
        hora_fin=str(h.hora_fin)[:5],
        precio_override=float(h.precio_override) if h.precio_override else None,
        activo=h.activo,
    ) for h in horarios]


@router.post("/", response_model=HorarioResponse, status_code=201)
async def crear_horario(
    data: HorarioCreate,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    await _verificar_pertenencia(data.cancha_id, current_user["id"], db)

    if data.dia_semana not in range(7):
        raise HTTPException(status_code=400, detail="dia_semana debe estar entre 0 (Lun) y 6 (Dom)")

    nuevo = HorarioDisponible(
        id=uuid.uuid4(),
        cancha_id=data.cancha_id,
        dia_semana=data.dia_semana,
        hora_inicio=_parse_time(data.hora_inicio),
        hora_fin=_parse_time(data.hora_fin),
        precio_override=data.precio_override,
        activo=data.activo,
    )
    db.add(nuevo)
    await db.commit()
    await db.refresh(nuevo)

    return HorarioResponse(
        id=nuevo.id,
        cancha_id=nuevo.cancha_id,
        dia_semana=nuevo.dia_semana,
        hora_inicio=str(nuevo.hora_inicio)[:5],
        hora_fin=str(nuevo.hora_fin)[:5],
        precio_override=float(nuevo.precio_override) if nuevo.precio_override else None,
        activo=nuevo.activo,
    )


@router.patch("/{horario_id}", response_model=HorarioResponse)
async def actualizar_horario(
    horario_id: uuid.UUID,
    data: HorarioUpdate,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(HorarioDisponible).where(HorarioDisponible.id == horario_id)
    )
    horario = result.scalar_one_or_none()
    if not horario:
        raise HTTPException(status_code=404, detail="Horario no encontrado")

    await _verificar_pertenencia(horario.cancha_id, current_user["id"], db)

    if data.dia_semana is not None:
        if data.dia_semana not in range(7):
            raise HTTPException(status_code=400, detail="dia_semana debe estar entre 0 y 6")
        horario.dia_semana = data.dia_semana
    if data.hora_inicio is not None:
        horario.hora_inicio = _parse_time(data.hora_inicio)
    if data.hora_fin is not None:
        horario.hora_fin = _parse_time(data.hora_fin)
    if data.precio_override is not None:
        horario.precio_override = data.precio_override
    if data.activo is not None:
        horario.activo = data.activo

    await db.commit()
    await db.refresh(horario)

    return HorarioResponse(
        id=horario.id,
        cancha_id=horario.cancha_id,
        dia_semana=horario.dia_semana,
        hora_inicio=str(horario.hora_inicio)[:5],
        hora_fin=str(horario.hora_fin)[:5],
        precio_override=float(horario.precio_override) if horario.precio_override else None,
        activo=horario.activo,
    )


@router.delete("/{horario_id}", status_code=204)
async def eliminar_horario(
    horario_id: uuid.UUID,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(HorarioDisponible).where(HorarioDisponible.id == horario_id)
    )
    horario = result.scalar_one_or_none()
    if not horario:
        raise HTTPException(status_code=404, detail="Horario no encontrado")

    await _verificar_pertenencia(horario.cancha_id, current_user["id"], db)
    await db.delete(horario)
    await db.commit()
