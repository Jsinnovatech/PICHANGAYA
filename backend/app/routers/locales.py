from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from math import radians, cos, sin, asin, sqrt
from typing import Optional, List
from datetime import date, time
import uuid  # noqa: F401 (used in path param type hints)

from app.core.database import get_db
from app.models.local import Local
from app.models.cancha import Cancha
from app.models.horario import HorarioDisponible
from app.models.reserva import Reserva, EstadoReservaEnum
from app.models.configuracion import Configuracion
from app.models.configuracion_pago import ConfiguracionPago
from app.schemas.locales import LocalResponse, CanchaResponse, SlotDisponibilidad

router = APIRouter(prefix="/locales", tags=["Locales"])


@router.get("/configuracion/pagos")
async def get_datos_pago(db: AsyncSession = Depends(get_db)):
    """Devuelve los datos de pago públicos (Yape, Plin, BCP, BBVA) sin auth."""
    result = await db.execute(select(Configuracion).where(Configuracion.id == 1))
    config = result.scalar_one_or_none()
    return {
        "yape_numero":   config.yape_numero   if config else None,
        "plin_numero":   config.plin_numero   if config else None,
        "cuenta_bcp":    config.cuenta_bcp    if config else None,
        "cuenta_bbva":   config.cuenta_bbva   if config else None,
        "titular":       config.razon_social  if config else "PichangaYa",
    }


@router.get("/{local_id}/medios-pago")
async def get_medios_pago_local(local_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """Devuelve los medios de pago configurados por el admin dueño del local (sin auth)."""
    # Obtener el admin_id del local
    local_r = await db.execute(select(Local).where(Local.id == local_id))
    local = local_r.scalar_one_or_none()
    if not local:
        raise HTTPException(status_code=404, detail="Local no encontrado")

    config_r = await db.execute(
        select(ConfiguracionPago).where(ConfiguracionPago.admin_id == local.admin_id)
    )
    config = config_r.scalar_one_or_none()

    return {
        "yape_numero":      config.yape_numero      if config else None,
        "qr_imagen_base64": config.qr_imagen_base64 if config else None,
        "cuenta_bcp":       config.cuenta_bcp       if config else None,
        "cuenta_bbva":      config.cuenta_bbva      if config else None,
    }


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

    # Traer canchas activas del local
    result = await db.execute(
        select(Cancha).where(
            Cancha.local_id == local_id,
            Cancha.activa == True
        )
    )
    canchas = result.scalars().all()

    # Calcular precio_dia / precio_noche por cancha desde HorarioDisponible
    respuesta = []
    for cancha in canchas:
        horarios_res = await db.execute(
            select(HorarioDisponible).where(
                HorarioDisponible.cancha_id == cancha.id,
                HorarioDisponible.activo == True
            )
        )
        horarios = horarios_res.scalars().all()

        precios_dia = [float(h.precio_override or cancha.precio_hora)
                       for h in horarios if h.hora_inicio.hour < 18]
        precios_noche = [float(h.precio_override or cancha.precio_hora)
                         for h in horarios if h.hora_inicio.hour >= 18]

        respuesta.append(CanchaResponse(
            id=cancha.id,
            local_id=cancha.local_id,
            nombre=cancha.nombre,
            capacidad=cancha.capacidad,
            precio_hora=float(cancha.precio_hora),
            precio_dia=min(precios_dia) if precios_dia else None,
            precio_noche=min(precios_noche) if precios_noche else None,
            superficie=cancha.superficie,
            foto_url=cancha.foto_url,
            activa=cancha.activa,
        ))

    return respuesta


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

    # Construir slots — genera sub-slots de 1 hora por cada HorarioDisponible.
    # El admin define un rango (ej. 08:00–22:00); el cliente ve 14 slots de 1h.
    slots = []
    for horario in horarios:
        precio = float(horario.precio_override) if horario.precio_override else precio_base

        # Convertir hora_inicio/hora_fin a minutos desde medianoche
        ini_min = horario.hora_inicio.hour * 60 + horario.hora_inicio.minute
        fin_h, fin_m = horario.hora_fin.hour, horario.hora_fin.minute
        # 00:00 como hora_fin significa medianoche = fin del día = 1440 min
        fin_min = 1440 if (fin_h == 0 and fin_m == 0) else fin_h * 60 + fin_m

        # Generar slots de 1 hora
        current = ini_min
        while current + 60 <= fin_min:
            next_min = current + 60
            slot_ini = time(current // 60, current % 60)
            # Si next_min == 1440 usamos time(0, 0) para representar medianoche
            slot_fin = time(0, 0) if next_min == 1440 else time(next_min // 60, next_min % 60)

            slots.append(SlotDisponibilidad(
                hora_inicio=f"{current // 60:02d}:{current % 60:02d}",
                hora_fin=f"{next_min % 1440 // 60:02d}:{next_min % 1440 % 60:02d}",
                disponible=not _slot_ocupado(slot_ini, slot_fin),
                precio=precio
            ))
            current += 60

    return slots