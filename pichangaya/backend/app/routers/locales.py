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
    horarios = horarios_result.scalars().all()

    if not horarios:
        return []

    # Query 2: reservas activas para esta cancha en esta fecha
    reservas_result = await db.execute(
        select(Reserva.hora_inicio).where(
            Reserva.cancha_id == cancha_id,
            Reserva.fecha == fecha,
            Reserva.estado.in_([
                EstadoReservaEnum.pending,
                EstadoReservaEnum.confirmed,
                EstadoReservaEnum.active
            ])
        )
    )
    # Solo traemos hora_inicio — es lo único que necesitamos
    horas_ocupadas = {str(r)[:5] for r in reservas_result.scalars().all()}
    # Set de strings "HH:MM" para búsqueda rápida

    # Query 3: precio base de la cancha (una sola vez fuera del loop)
    cancha_result = await db.execute(select(Cancha).where(Cancha.id == cancha_id))
    cancha = cancha_result.scalar_one_or_none()
    precio_base = float(cancha.precio_hora) if cancha else 0.0
    # Sacamos el precio ANTES del loop para no repetir la query

    # Construir slots — sin queries dentro del loop
    slots = []
    for horario in horarios:
        hora_inicio_str = str(horario.hora_inicio)[:5]
        hora_fin_str = str(horario.hora_fin)[:5]

        precio = float(horario.precio_override) if horario.precio_override else precio_base
        # precio_override tiene prioridad sobre el precio base

        slots.append(SlotDisponibilidad(
            hora_inicio=hora_inicio_str,
            hora_fin=hora_fin_str,
            disponible=hora_inicio_str not in horas_ocupadas,
            precio=precio
        ))

    return slots