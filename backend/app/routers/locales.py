from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from math import radians, cos, sin, asin, sqrt
from typing import Optional, List
from datetime import date
import uuid

from app.core.database import get_db
from app.models.local import Local
from app.models.cancha import Cancha
from app.models.horario import HorarioDisponible
from app.models.reserva import Reserva, EstadoReservaEnum
from app.schemas.locales import LocalResponse, CanchaResponse, SlotDisponibilidad

router = APIRouter(prefix="/locales", tags=["Locales"])


def calcular_distancia_km(lat1, lon1, lat2, lon2) -> float:
    # Fórmula Haversine — misma del prototipo HTML
    R = 6371
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1)*cos(lat2)*sin(dlon/2)**2
    return round(R * 2 * asin(sqrt(a)), 2)


@router.get("/", response_model=List[LocalResponse])
async def get_locales(
    lat: Optional[float] = Query(None),
    lng: Optional[float] = Query(None),
    radio: float = Query(2.0),
    db: AsyncSession = Depends(get_db)
):
    # UNA SOLA QUERY: trae locales + cuenta canchas + precio mínimo
    # Usando GROUP BY para calcular todo en PostgreSQL de una vez
    # Esto evita el problema de hacer 1 query por cada local
    result = await db.execute(
        select(
            Local,
            func.count(Cancha.id).label("num_canchas"),
            # func.count() equivale al COUNT() de SQL
            # .label("num_canchas") le da nombre al campo calculado
            func.min(Cancha.precio_hora).label("precio_desde")
            # func.min() equivale al MIN() de SQL
        )
        .outerjoin(Cancha, (Cancha.local_id == Local.id) & (Cancha.activa == True))
        # outerjoin → LEFT JOIN: incluye locales aunque no tengan canchas
        # La condición filtra solo canchas activas en el JOIN
        .where(Local.activo == True)
        .group_by(Local.id)
        # GROUP BY agrupa los resultados por local
        # Necesario para usar COUNT y MIN
    )
    filas = result.all()
    # Cada fila es una tupla: (Local, num_canchas, precio_desde)

    respuesta = []
    for local, num_canchas, precio_desde in filas:
        # Calcular distancia si el usuario envió GPS
        distancia_km = None
        if lat is not None and lng is not None:
            distancia_km = calcular_distancia_km(lat, lng, float(local.lat), float(local.lng))
            if distancia_km > radio:
                continue
                # Saltar locales fuera del radio

        respuesta.append(LocalResponse(
            id=local.id,
            nombre=local.nombre,
            direccion=local.direccion,
            lat=float(local.lat),
            lng=float(local.lng),
            telefono=local.telefono,
            foto_url=local.foto_url,
            distancia_km=distancia_km,
            num_canchas=num_canchas,
            precio_desde=float(precio_desde) if precio_desde else None
        ))

    # Ordenar por distancia si se enviaron coordenadas
    if lat is not None:
        respuesta.sort(key=lambda x: x.distancia_km or 999)

    return respuesta


@router.get("/{local_id}/canchas", response_model=List[CanchaResponse])
async def get_canchas_por_local(
    local_id: uuid.UUID,
    db: AsyncSession = Depends(get_db)
):
    # Verificar que el local existe
    result = await db.execute(select(Local).where(Local.id == local_id))
    local = result.scalar_one_or_none()
    if not local:
        raise HTTPException(status_code=404, detail="Local no encontrado")

    # Traer canchas activas del local — UNA sola query
    result = await db.execute(
        select(Cancha).where(
            Cancha.local_id == local_id,
            Cancha.activa == True
        )
    )
    return result.scalars().all()


@router.get("/{local_id}/canchas/{cancha_id}/disponibilidad", response_model=List[SlotDisponibilidad])
async def get_disponibilidad(
    local_id: uuid.UUID,
    cancha_id: uuid.UUID,
    fecha: date = Query(...),
    db: AsyncSession = Depends(get_db)
):
    dia_semana = fecha.weekday()
    # 0=Lunes ... 6=Domingo

    # Query 1: horarios del día para esta cancha
    horarios_result = await db.execute(
        select(HorarioDisponible).where(
            HorarioDisponible.cancha_id == cancha_id,
            HorarioDisponible.dia_semana == dia_semana,
            HorarioDisponible.activo == True
        ).order_by(HorarioDisponible.hora_inicio)
    )
    horarios_raw = horarios_result.scalars().all()

    # Reordenar: medianoche (00:xx) va al FINAL, después del 23:00
    def _sort_hora(h):
        hora = h.hora_inicio
        # time(0, x) es medianoche → lo tratamos como hora 24 para que vaya al final
        return (24 + hora.minute / 60) if hora.hour == 0 else hora.hour + hora.minute / 60

    horarios = sorted(horarios_raw, key=_sort_hora)

    if not horarios:
        return []

    # Query 2: reservas activas → necesitamos hora_inicio Y hora_fin para range overlap
    reservas_result = await db.execute(
        select(Reserva.hora_inicio, Reserva.hora_fin).where(
            Reserva.cancha_id == cancha_id,
            Reserva.fecha == fecha,
            Reserva.estado.in_([
                EstadoReservaEnum.pending,
                EstadoReservaEnum.confirmed,
                EstadoReservaEnum.active
            ])
        )
    )
    reservas_activas = reservas_result.fetchall()  # lista de (hora_inicio, hora_fin)

    def _t_min(t) -> int:
        """Convierte time a minutos. Medianoche (00:00) = 1440."""
        if t.hour == 0 and t.minute == 0:
            return 1440
        return t.hour * 60 + t.minute

    def _slot_ocupado(s_ini, s_fin) -> bool:
        s_start = _t_min(s_ini)
        s_end   = _t_min(s_fin)
        for r_ini, r_fin in reservas_activas:
            if _t_min(r_ini) < s_end and _t_min(r_fin) > s_start:
                return True
        return False

    # Query 3: precio base de la cancha
    cancha_result = await db.execute(select(Cancha).where(Cancha.id == cancha_id))
    cancha = cancha_result.scalar_one_or_none()
    precio_base = float(cancha.precio_hora) if cancha else 0.0

    # Construir slots
    slots = []
    for horario in horarios:
        hora_inicio_str = str(horario.hora_inicio)[:5]
        hora_fin_str    = str(horario.hora_fin)[:5]
        precio = float(horario.precio_override) if horario.precio_override else precio_base

        slots.append(SlotDisponibilidad(
            hora_inicio=hora_inicio_str,
            hora_fin=hora_fin_str,
            disponible=not _slot_ocupado(horario.hora_inicio, horario.hora_fin),
            precio=precio
        ))

    return slots