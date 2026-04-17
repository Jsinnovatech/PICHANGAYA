from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from datetime import date, datetime, timezone
import uuid
import logging

from app.core.database import get_db
from app.core.dependencies import require_admin
from app.models.reserva import Reserva, EstadoReservaEnum
from app.models.pago import Pago, EstadoPagoEnum
from app.models.user import User, RolEnum
from app.models.cancha import Cancha
from app.models.local import Local
from app.models.comprobante import Comprobante, EstadoComprobanteEnum
from app.notificaciones import notif_reserva_confirmada, notif_reserva_rechazada
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["Admin"])
# ══════════════════════════════════════════════
# SCHEMAS
# ══════════════════════════════════════════════

class ReservaAdminResponse(BaseModel):
    id: uuid.UUID
    codigo: str
    cliente_nombre: str
    cliente_celular: str
    cancha_nombre: Optional[str] = None
    local_nombre: Optional[str] = None
    fecha: date
    hora_inicio: str
    hora_fin: str
    precio_total: float
    estado: str
    tipo_doc: Optional[str] = None
    metodo_pago: Optional[str] = None
    voucher_url: Optional[str] = None
    pago_estado: Optional[str] = None
    pago_id: Optional[uuid.UUID] = None

    class Config:
        from_attributes = True


class PagoAdminResponse(BaseModel):
    id: uuid.UUID
    reserva_id: uuid.UUID
    reserva_codigo: Optional[str] = None
    cliente_nombre: Optional[str] = None
    cliente_celular: Optional[str] = None
    monto: float
    metodo: str
    estado: str
    voucher_url: Optional[str] = None
    fecha: Optional[str] = None

    class Config:
        from_attributes = True


class ClienteAdminResponse(BaseModel):
    id: uuid.UUID
    nombre: str
    celular: str
    dni: Optional[str] = None
    activo: bool
    total_reservas: int = 0
    total_gastado: float = 0.0

    class Config:
        from_attributes = True


class VerificarPagoRequest(BaseModel):
    accion: str
    motivo: Optional[str] = None


class CambiarEstadoReservaRequest(BaseModel):
    estado: str
    notas: Optional[str] = None


# ══════════════════════════════════════════════
# DASHBOARD
# ══════════════════════════════════════════════

@router.get("/dashboard")
async def admin_dashboard(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    import asyncio
    import calendar
    from datetime import datetime, timezone, timedelta, date as date_type

    LIMA_TZ = timezone(timedelta(hours=-5))
    hoy = datetime.now(LIMA_TZ).date()
    primer_dia_mes = hoy.replace(day=1)

    # ── Todos los stats en paralelo (una sola ida a Railway) ─────
    (
        reservas_hoy_r,
        reservas_pendientes_r,
        ingresos_hoy_r,
        total_clientes_r,
        pagos_pendientes_r,
        total_reservas_r,
        ingresos_mes_r,
        metodo_rows_r,
        ultimas_reservas_r,
    ) = await asyncio.gather(
        db.execute(select(func.count(Reserva.id)).where(Reserva.fecha == hoy)),
        db.execute(select(func.count(Reserva.id)).where(Reserva.estado == EstadoReservaEnum.pending)),
        db.execute(select(func.sum(Pago.monto)).where(
            Pago.estado == EstadoPagoEnum.verificado,
            func.date(Pago.created_at) == hoy,
        )),
        db.execute(select(func.count(User.id)).where(User.rol == RolEnum.cliente, User.activo == True)),
        db.execute(select(func.count(Pago.id)).where(Pago.estado == EstadoPagoEnum.pendiente)),
        db.execute(select(func.count(Reserva.id))),
        db.execute(select(func.sum(Pago.monto)).where(
            Pago.estado == EstadoPagoEnum.verificado,
            func.date(Pago.created_at) >= primer_dia_mes,
            func.date(Pago.created_at) <= hoy,
        )),
        db.execute(
            select(Pago.metodo, func.count(Pago.id), func.sum(Pago.monto))
            .where(Pago.estado == EstadoPagoEnum.verificado)
            .group_by(Pago.metodo)
        ),
        db.execute(select(Reserva).order_by(Reserva.created_at.desc()).limit(20)),
    )

    reservas_hoy      = reservas_hoy_r.scalar() or 0
    reservas_pendientes = reservas_pendientes_r.scalar() or 0
    ingresos_hoy      = float(ingresos_hoy_r.scalar() or 0)
    total_clientes    = total_clientes_r.scalar() or 0
    pagos_pendientes  = pagos_pendientes_r.scalar() or 0
    total_reservas    = total_reservas_r.scalar() or 0
    ingresos_mes      = float(ingresos_mes_r.scalar() or 0)
    metodo_rows       = metodo_rows_r.fetchall()
    ultimas_reservas  = ultimas_reservas_r.scalars().all()

    pagos_por_metodo = [
        {"metodo": row[0].value, "cantidad": row[1], "total": float(row[2] or 0)}
        for row in metodo_rows
    ]

    # ── Reservas por mes (últimos 6 meses) — 1 query ─────────────
    meses_info = []
    for i in range(5, -1, -1):
        year  = hoy.year
        month = hoy.month - i
        while month <= 0:
            month += 12
            year  -= 1
        primer = date_type(year, month, 1)
        ultimo = date_type(year, month, calendar.monthrange(year, month)[1])
        meses_info.append((primer, ultimo))

    fecha_inicio_rango = meses_info[0][0]
    fecha_fin_rango    = meses_info[-1][1]

    reservas_fechas = (await db.execute(
        select(Reserva.fecha).where(
            Reserva.fecha >= fecha_inicio_rango,
            Reserva.fecha <= fecha_fin_rango,
            Reserva.estado != EstadoReservaEnum.canceled,
        )
    )).scalars().all()

    reservas_por_mes = [
        {"mes": primer.strftime("%b"), "cantidad": sum(1 for f in reservas_fechas if primer <= f <= ultimo)}
        for primer, ultimo in meses_info
    ]

    # ── Últimas reservas: batch lookup de clientes y canchas ─────
    if ultimas_reservas:
        cliente_ids = list({r.cliente_id for r in ultimas_reservas})
        cancha_ids  = list({r.cancha_id  for r in ultimas_reservas})
        clientes_rows, canchas_rows = await asyncio.gather(
            db.execute(select(User).where(User.id.in_(cliente_ids))),
            db.execute(select(Cancha).where(Cancha.id.in_(cancha_ids))),
        )
        clientes_map = {u.id: u for u in clientes_rows.scalars().all()}
        canchas_map  = {c.id: c for c in canchas_rows.scalars().all()}
    else:
        clientes_map = {}
        canchas_map  = {}

    ultimas_lista = [
        {
            "codigo":  r.codigo,
            "cliente": clientes_map[r.cliente_id].nombre if r.cliente_id in clientes_map else "—",
            "cancha":  canchas_map[r.cancha_id].nombre   if r.cancha_id  in canchas_map  else "—",
            "fecha":   str(r.fecha),
            "hora":    str(r.hora_inicio)[:5],
            "estado":  r.estado.value,
            "monto":   float(r.precio_total),
        }
        for r in ultimas_reservas
    ]

    return {
        "stats": {
            "reservas_hoy":        reservas_hoy,
            "reservas_pendientes": reservas_pendientes,
            "ingresos_hoy":        ingresos_hoy,
            "total_clientes":      total_clientes,
            "pagos_pendientes":    pagos_pendientes,
            "total_reservas":      total_reservas,
            "ingresos_mes":        ingresos_mes,
        },
        "pagos_por_metodo": pagos_por_metodo,
        "reservas_por_mes": reservas_por_mes,
        "ultimas_reservas": ultimas_lista,
    }


# ══════════════════════════════════════════════
# RESERVAS
# ══════════════════════════════════════════════

@router.get("/reservas", response_model=List[ReservaAdminResponse])
async def admin_get_reservas(
    estado: Optional[str] = None,
    fecha: Optional[date] = None,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    try:
        query = select(Reserva).order_by(Reserva.created_at.desc())

        if estado:
            try:
                estado_enum = EstadoReservaEnum(estado)
                query = query.where(Reserva.estado == estado_enum)
            except ValueError:
                raise HTTPException(status_code=400, detail=f"Estado inválido: {estado}")

        if fecha:
            query = query.where(Reserva.fecha == fecha)

        result = await db.execute(query)
        reservas = result.scalars().all()

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error al consultar reservas en BD: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error al consultar la base de datos: {str(e)}"
        )

    if not reservas:
        return []

    import asyncio

    # Batch queries en paralelo — sin N+1
    reserva_ids = [r.id for r in reservas]
    cliente_ids = list({r.cliente_id for r in reservas})
    cancha_ids  = list({r.cancha_id  for r in reservas})

    clientes_rows, canchas_rows, pagos_rows = await asyncio.gather(
        db.execute(select(User).where(User.id.in_(cliente_ids))),
        db.execute(select(Cancha).where(Cancha.id.in_(cancha_ids))),
        db.execute(select(Pago).where(Pago.reserva_id.in_(reserva_ids))),
    )
    clientes_map = {u.id: u for u in clientes_rows.scalars().all()}
    canchas_map  = {c.id: c for c in canchas_rows.scalars().all()}

    pagos_map: dict = {}
    for pago in pagos_rows.scalars().all():
        pagos_map.setdefault(pago.reserva_id, pago)

    local_ids = list({c.local_id for c in canchas_map.values()})
    locales_map = {
        l.id: l for l in (await db.execute(
            select(Local).where(Local.id.in_(local_ids))
        )).scalars().all()
    } if local_ids else {}

    respuesta = []
    for reserva in reservas:
        try:
            cliente = clientes_map.get(reserva.cliente_id)
            cancha  = canchas_map.get(reserva.cancha_id)
            local   = locales_map.get(cancha.local_id) if cancha else None
            pago    = pagos_map.get(reserva.id)

            respuesta.append(ReservaAdminResponse(
                id=reserva.id,
                codigo=reserva.codigo,
                cliente_nombre=cliente.nombre if cliente else "Desconocido",
                cliente_celular=cliente.celular if cliente else "",
                cancha_nombre=cancha.nombre if cancha else None,
                local_nombre=local.nombre if local else None,
                fecha=reserva.fecha,
                hora_inicio=str(reserva.hora_inicio)[:5],
                hora_fin=str(reserva.hora_fin)[:5],
                precio_total=float(reserva.precio_total),
                estado=reserva.estado.value,
                tipo_doc=reserva.tipo_doc.value if reserva.tipo_doc else None,
                metodo_pago=pago.metodo.value if pago else None,
                voucher_url=pago.voucher_url if pago else None,
                pago_estado=pago.estado.value if pago else None,
                pago_id=pago.id if pago else None
            ))
        except Exception as e:
            logger.error(f"Error procesando reserva {reserva.id}: {e}", exc_info=True)
            continue

    return respuesta


@router.delete("/reservas/{reserva_id}")
async def admin_eliminar_reserva(
    reserva_id: uuid.UUID,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Reserva).where(Reserva.id == reserva_id))
    reserva = result.scalar_one_or_none()

    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    # Cancelar el pago asociado primero
    pago_result = await db.execute(select(Pago).where(Pago.reserva_id == reserva.id))
    pago = pago_result.scalars().first()
    if pago:
        pago.estado = EstadoPagoEnum.rechazado

    reserva.estado = EstadoReservaEnum.canceled
    await db.commit()

    return {"mensaje": f"Reserva {reserva.codigo} cancelada/eliminada correctamente"}


@router.patch("/reservas/{reserva_id}/estado")
async def admin_cambiar_estado_reserva(
    reserva_id: uuid.UUID,
    data: CambiarEstadoReservaRequest,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Reserva).where(Reserva.id == reserva_id))
    reserva = result.scalar_one_or_none()

    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    try:
        nuevo_estado = EstadoReservaEnum(data.estado)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Estado inválido: {data.estado}")

    reserva.estado = nuevo_estado
    if data.notas:
        reserva.notas = data.notas

    await db.commit()
    await db.refresh(reserva)

    return {
        "mensaje": f"Reserva {reserva.codigo} actualizada a {nuevo_estado.value}",
        "reserva_id": str(reserva.id),
        "nuevo_estado": nuevo_estado.value
    }


# ══════════════════════════════════════════════
# PAGOS
# ══════════════════════════════════════════════

@router.get("/pagos", response_model=List[PagoAdminResponse])
async def admin_get_pagos(
    estado: Optional[str] = None,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    query = select(Pago).order_by(Pago.created_at.desc())

    if estado:
        try:
            estado_enum = EstadoPagoEnum(estado)
            query = query.where(Pago.estado == estado_enum)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Estado inválido: {estado}")

    result = await db.execute(query)
    pagos = result.scalars().all()

    respuesta = []
    for pago in pagos:
        cliente_result = await db.execute(select(User).where(User.id == pago.cliente_id))
        cliente = cliente_result.scalar_one_or_none()

        reserva_result = await db.execute(select(Reserva).where(Reserva.id == pago.reserva_id))
        reserva = reserva_result.scalar_one_or_none()

        respuesta.append(PagoAdminResponse(
            id=pago.id,
            reserva_id=pago.reserva_id,
            reserva_codigo=reserva.codigo if reserva else None,
            cliente_nombre=cliente.nombre if cliente else None,
            cliente_celular=cliente.celular if cliente else None,
            monto=float(pago.monto),
            metodo=pago.metodo.value,
            estado=pago.estado.value,
            voucher_url=pago.voucher_url,
            fecha=str(pago.created_at.date()) if pago.created_at else None
        ))

    return respuesta


@router.patch("/pagos/{pago_id}/verificar")
async def admin_verificar_pago(
    pago_id: uuid.UUID,
    data: VerificarPagoRequest,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Pago).where(Pago.id == pago_id))
    pago = result.scalar_one_or_none()

    if not pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado")

    reserva_result = await db.execute(select(Reserva).where(Reserva.id == pago.reserva_id))
    reserva = reserva_result.scalar_one_or_none()

    # ── Datos extra para la notificación ──────────────────────
    cancha = None
    if reserva:
        cancha_result = await db.execute(select(Cancha).where(Cancha.id == reserva.cancha_id))
        cancha = cancha_result.scalar_one_or_none()

    if data.accion == "aprobar":
        pago.estado = EstadoPagoEnum.verificado
        pago.verificado_por = uuid.UUID(current_user["id"])
        if reserva:
            reserva.estado = EstadoReservaEnum.confirmed
        mensaje = f"Pago aprobado — Reserva {reserva.codigo if reserva else ''} confirmada"

    elif data.accion == "rechazar":
        pago.estado = EstadoPagoEnum.rechazado
        if reserva:
            reserva.estado = EstadoReservaEnum.canceled
            if data.motivo:
                reserva.notas = f"Pago rechazado: {data.motivo}"
        mensaje = "Pago rechazado — Reserva cancelada"

    else:
        raise HTTPException(status_code=400, detail="Acción inválida. Use 'aprobar' o 'rechazar'")

    # ── Commit principal (CRÍTICO — siempre se guarda) ─────────
    await db.commit()

    # ── Notificar al cliente (no crítico) ──────────────────────
    try:
        if reserva:
            if data.accion == "aprobar":
                await notif_reserva_confirmada(
                    db=db,
                    cliente_id=reserva.cliente_id,
                    codigo=reserva.codigo,
                    fecha=str(reserva.fecha),
                    hora=str(reserva.hora_inicio)[:5],
                    cancha_nombre=cancha.nombre if cancha else "la cancha"
                )
            elif data.accion == "rechazar":
                await notif_reserva_rechazada(
                    db=db,
                    cliente_id=reserva.cliente_id,
                    codigo=reserva.codigo,
                    motivo=data.motivo or "Pago no verificado"
                )
            await db.commit()
    except Exception as e:
        logger.warning(f"Notificación al cliente no enviada (pago igual procesado): {e}")

    return {"mensaje": mensaje, "pago_id": str(pago_id), "accion": data.accion}


# ══════════════════════════════════════════════
# CLIENTES
# ══════════════════════════════════════════════

@router.get("/clientes", response_model=List[ClienteAdminResponse])
async def admin_get_clientes(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(User).where(User.rol == RolEnum.cliente).order_by(User.created_at.desc())
    )
    clientes = result.scalars().all()

    respuesta = []
    for cliente in clientes:
        reservas_result = await db.execute(
            select(func.count(Reserva.id)).where(Reserva.cliente_id == cliente.id)
        )
        total_reservas = reservas_result.scalar() or 0

        pagos_result = await db.execute(
            select(func.sum(Pago.monto)).where(
                Pago.cliente_id == cliente.id,
                Pago.estado == EstadoPagoEnum.verificado
            )
        )
        total_gastado = float(pagos_result.scalar() or 0)

        respuesta.append(ClienteAdminResponse(
            id=cliente.id,
            nombre=cliente.nombre,
            celular=cliente.celular,
            dni=cliente.dni,
            activo=cliente.activo,
            total_reservas=total_reservas,
            total_gastado=total_gastado
        ))

    return respuesta


@router.patch("/clientes/{cliente_id}/toggle")
async def admin_toggle_cliente(
    cliente_id: uuid.UUID,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(User).where(User.id == cliente_id, User.rol == RolEnum.cliente)
    )
    cliente = result.scalar_one_or_none()

    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")

    cliente.activo = not cliente.activo
    await db.commit()

    return {
        "mensaje": f"Cliente {cliente.nombre} {'activado' if cliente.activo else 'desactivado'}",
        "activo": cliente.activo
    }


# ══════════════════════════════════════════════
# CANCHAS
# ══════════════════════════════════════════════

class CanchaAdminResponse(BaseModel):
    id: uuid.UUID
    local_id: uuid.UUID
    local_nombre: Optional[str] = None
    nombre: str
    descripcion: Optional[str] = None
    capacidad: int
    precio_hora: float
    superficie: Optional[str] = None
    activa: bool
    class Config: from_attributes = True

class CanchaCreateRequest(BaseModel):
    local_id: uuid.UUID
    nombre: str
    descripcion: Optional[str] = None
    capacidad: int = 10
    precio_hora: float
    superficie: Optional[str] = None

class CanchaUpdateRequest(BaseModel):
    nombre: Optional[str] = None
    descripcion: Optional[str] = None
    capacidad: Optional[int] = None
    precio_hora: Optional[float] = None
    superficie: Optional[str] = None


@router.get("/canchas", response_model=List[CanchaAdminResponse])
async def admin_get_canchas(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Cancha).order_by(Cancha.created_at.desc()))
    canchas = result.scalars().all()
    respuesta = []
    for c in canchas:
        local_r = await db.execute(select(Local).where(Local.id == c.local_id))
        local = local_r.scalar_one_or_none()
        respuesta.append(CanchaAdminResponse(
            id=c.id, local_id=c.local_id,
            local_nombre=local.nombre if local else None,
            nombre=c.nombre, descripcion=c.descripcion,
            capacidad=c.capacidad, precio_hora=float(c.precio_hora),
            superficie=c.superficie, activa=c.activa
        ))
    return respuesta


@router.post("/canchas", response_model=CanchaAdminResponse, status_code=201)
async def admin_crear_cancha(
    data: CanchaCreateRequest,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    local_r = await db.execute(
        select(Local).where(
            Local.id == data.local_id,
            Local.admin_id == uuid.UUID(current_user["id"])
        )
    )
    local = local_r.scalar_one_or_none()
    if not local:
        raise HTTPException(status_code=404, detail="Local no encontrado o no te pertenece")
    cancha = Cancha(
        local_id=data.local_id, nombre=data.nombre,
        descripcion=data.descripcion, capacidad=data.capacidad,
        precio_hora=data.precio_hora, superficie=data.superficie
    )
    db.add(cancha)
    await db.commit()
    await db.refresh(cancha)
    return CanchaAdminResponse(
        id=cancha.id, local_id=cancha.local_id, local_nombre=local.nombre,
        nombre=cancha.nombre, descripcion=cancha.descripcion,
        capacidad=cancha.capacidad, precio_hora=float(cancha.precio_hora),
        superficie=cancha.superficie, activa=cancha.activa
    )


@router.patch("/canchas/{cancha_id}/toggle")
async def admin_toggle_cancha(
    cancha_id: uuid.UUID,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Cancha)
        .join(Local, Local.id == Cancha.local_id)
        .where(Cancha.id == cancha_id, Local.admin_id == uuid.UUID(current_user["id"]))
    )
    cancha = result.scalar_one_or_none()
    if not cancha:
        raise HTTPException(status_code=404, detail="Cancha no encontrada o no te pertenece")
    cancha.activa = not cancha.activa
    await db.commit()
    return {"mensaje": f"Cancha {cancha.nombre} {'activada' if cancha.activa else 'desactivada'}", "activa": cancha.activa}


@router.patch("/canchas/{cancha_id}")
async def admin_actualizar_cancha(
    cancha_id: uuid.UUID,
    data: CanchaUpdateRequest,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Cancha)
        .join(Local, Local.id == Cancha.local_id)
        .where(Cancha.id == cancha_id, Local.admin_id == uuid.UUID(current_user["id"]))
    )
    cancha = result.scalar_one_or_none()
    if not cancha:
        raise HTTPException(status_code=404, detail="Cancha no encontrada o no te pertenece")
    if data.nombre is not None: cancha.nombre = data.nombre
    if data.descripcion is not None: cancha.descripcion = data.descripcion
    if data.capacidad is not None: cancha.capacidad = data.capacidad
    if data.precio_hora is not None: cancha.precio_hora = data.precio_hora
    if data.superficie is not None: cancha.superficie = data.superficie
    await db.commit()
    return {"mensaje": "Cancha actualizada"}


# ══════════════════════════════════════════════
# TIMERS
# ══════════════════════════════════════════════

class TimerReservaResponse(BaseModel):
    id: uuid.UUID
    codigo: str
    cliente_nombre: str
    cliente_celular: str
    cancha_nombre: Optional[str] = None
    fecha: date
    hora_inicio: str
    hora_fin: str
    estado: str
    precio_total: float
    class Config: from_attributes = True


@router.get("/timers/hoy", response_model=List[TimerReservaResponse])
async def admin_timers_hoy(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    hoy = datetime.now(timezone.utc).date()
    result = await db.execute(
        select(Reserva).where(
            Reserva.fecha == hoy,
            Reserva.estado.in_([EstadoReservaEnum.confirmed, EstadoReservaEnum.active])
        ).order_by(Reserva.hora_inicio)
    )
    reservas = result.scalars().all()
    respuesta = []
    for r in reservas:
        cliente = (await db.execute(select(User).where(User.id == r.cliente_id))).scalar_one_or_none()
        cancha = (await db.execute(select(Cancha).where(Cancha.id == r.cancha_id))).scalar_one_or_none()
        respuesta.append(TimerReservaResponse(
            id=r.id, codigo=r.codigo,
            cliente_nombre=cliente.nombre if cliente else "—",
            cliente_celular=cliente.celular if cliente else "",
            cancha_nombre=cancha.nombre if cancha else None,
            fecha=r.fecha,
            hora_inicio=str(r.hora_inicio)[:5],
            hora_fin=str(r.hora_fin)[:5],
            estado=r.estado.value,
            precio_total=float(r.precio_total)
        ))
    return respuesta


@router.patch("/timers/{reserva_id}/iniciar")
async def admin_iniciar_timer(
    reserva_id: uuid.UUID,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Reserva).where(Reserva.id == reserva_id))
    reserva = result.scalar_one_or_none()
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")
    if reserva.estado != EstadoReservaEnum.confirmed:
        raise HTTPException(status_code=400, detail="Solo se puede iniciar una reserva confirmada")
    reserva.estado = EstadoReservaEnum.active
    await db.commit()
    return {"mensaje": f"Partida {reserva.codigo} iniciada", "estado": "active"}


@router.patch("/timers/{reserva_id}/finalizar")
async def admin_finalizar_timer(
    reserva_id: uuid.UUID,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Reserva).where(Reserva.id == reserva_id))
    reserva = result.scalar_one_or_none()
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")
    if reserva.estado != EstadoReservaEnum.active:
        raise HTTPException(status_code=400, detail="Solo se puede finalizar una partida activa")
    reserva.estado = EstadoReservaEnum.done
    await db.commit()
    return {"mensaje": f"Partida {reserva.codigo} finalizada", "estado": "done"}


# ══════════════════════════════════════════════
# FACTURACION
# ══════════════════════════════════════════════

class FacturacionItemResponse(BaseModel):
    reserva_id: uuid.UUID
    codigo: str
    cliente_nombre: str
    cliente_celular: str
    cancha_nombre: Optional[str] = None
    fecha: date
    monto: float
    metodo_pago: str
    tipo_doc: Optional[str] = None
    comprobante_estado: Optional[str] = None
    comprobante_serie: Optional[str] = None
    comprobante_numero: Optional[int] = None
    pdf_url: Optional[str] = None
    fecha_pago: Optional[str] = None
    class Config: from_attributes = True


@router.get("/facturacion", response_model=List[FacturacionItemResponse])
async def admin_get_facturacion(
    tipo_doc: Optional[str] = None,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    query = select(Pago).where(Pago.estado == EstadoPagoEnum.verificado).order_by(Pago.created_at.desc())
    result = await db.execute(query)
    pagos = result.scalars().all()

    respuesta = []
    for pago in pagos:
        reserva = (await db.execute(select(Reserva).where(Reserva.id == pago.reserva_id))).scalar_one_or_none()
        if not reserva:
            continue
        if tipo_doc and (reserva.tipo_doc is None or reserva.tipo_doc.value != tipo_doc):
            continue
        cliente = (await db.execute(select(User).where(User.id == pago.cliente_id))).scalar_one_or_none()
        cancha = (await db.execute(select(Cancha).where(Cancha.id == reserva.cancha_id))).scalar_one_or_none()
        comp = (await db.execute(select(Comprobante).where(Comprobante.reserva_id == reserva.id))).scalar_one_or_none()

        respuesta.append(FacturacionItemResponse(
            reserva_id=reserva.id, codigo=reserva.codigo,
            cliente_nombre=cliente.nombre if cliente else "—",
            cliente_celular=cliente.celular if cliente else "",
            cancha_nombre=cancha.nombre if cancha else None,
            fecha=reserva.fecha, monto=float(pago.monto),
            metodo_pago=pago.metodo.value,
            tipo_doc=reserva.tipo_doc.value if reserva.tipo_doc else None,
            comprobante_estado=comp.estado.value if comp else None,
            comprobante_serie=comp.serie if comp else None,
            comprobante_numero=comp.numero if comp else None,
            pdf_url=comp.pdf_url if comp else None,
            fecha_pago=str(pago.created_at.date()) if pago.created_at else None
        ))
    return respuesta


@router.get("/facturacion/stats")
async def admin_facturacion_stats(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    from app.models.reserva import TipoDocEnum
    pagos_verif = (await db.execute(select(Pago).where(Pago.estado == EstadoPagoEnum.verificado))).scalars().all()
    total_ingresos = sum(float(p.monto) for p in pagos_verif)

    boletas = facturas = sin_tipo = 0
    for p in pagos_verif:
        r = (await db.execute(select(Reserva).where(Reserva.id == p.reserva_id))).scalar_one_or_none()
        if r:
            if r.tipo_doc and r.tipo_doc.value == "boleta": boletas += 1
            elif r.tipo_doc and r.tipo_doc.value == "factura": facturas += 1
            else: sin_tipo += 1

    hoy = datetime.now(timezone.utc).date()
    primer_dia_mes = hoy.replace(day=1)
    ingresos_mes = float((await db.execute(
        select(func.sum(Pago.monto)).where(
            Pago.estado == EstadoPagoEnum.verificado,
            func.date(Pago.created_at) >= primer_dia_mes
        )
    )).scalar() or 0)

    return {
        "total_boletas": boletas,
        "total_facturas": facturas,
        "sin_comprobante": sin_tipo,
        "ingresos_total": total_ingresos,
        "ingresos_mes": ingresos_mes
    }


# ══════════════════════════════════════════════
# LOCALES — CRUD del admin sobre sus propios locales
# ══════════════════════════════════════════════

class LocalAdminResponse(BaseModel):
    id: uuid.UUID
    nombre: str
    direccion: str
    lat: float
    lng: float
    telefono: Optional[str] = None
    descripcion: Optional[str] = None
    foto_url: Optional[str] = None
    activo: bool
    class Config: from_attributes = True


class LocalCreateRequest(BaseModel):
    nombre: str
    direccion: str
    lat: float
    lng: float
    telefono: Optional[str] = None
    descripcion: Optional[str] = None
    foto_url: Optional[str] = None


class LocalUpdateRequest(BaseModel):
    nombre: Optional[str] = None
    direccion: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    telefono: Optional[str] = None
    descripcion: Optional[str] = None
    foto_url: Optional[str] = None
    activo: Optional[bool] = None


@router.get("/locales", response_model=List[LocalAdminResponse])
async def admin_get_locales(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Retorna los locales del admin autenticado."""
    result = await db.execute(
        select(Local)
        .where(Local.admin_id == uuid.UUID(current_user["id"]))
        .order_by(Local.created_at.desc())
    )
    return result.scalars().all()


@router.post("/locales", response_model=LocalAdminResponse, status_code=201)
async def admin_crear_local(
    data: LocalCreateRequest,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Crea un nuevo local y lo asocia al admin autenticado."""
    local = Local(
        admin_id=uuid.UUID(current_user["id"]),
        nombre=data.nombre,
        direccion=data.direccion,
        lat=data.lat,
        lng=data.lng,
        telefono=data.telefono,
        descripcion=data.descripcion,
        foto_url=data.foto_url,
    )
    db.add(local)
    await db.commit()
    await db.refresh(local)
    return local


@router.patch("/locales/{local_id}", response_model=LocalAdminResponse)
async def admin_actualizar_local(
    local_id: uuid.UUID,
    data: LocalUpdateRequest,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Actualiza un local del admin autenticado."""
    result = await db.execute(
        select(Local).where(
            Local.id == local_id,
            Local.admin_id == uuid.UUID(current_user["id"])
        )
    )
    local = result.scalar_one_or_none()
    if not local:
        raise HTTPException(status_code=404, detail="Local no encontrado")

    if data.nombre      is not None: local.nombre      = data.nombre
    if data.direccion   is not None: local.direccion   = data.direccion
    if data.lat         is not None: local.lat         = data.lat
    if data.lng         is not None: local.lng         = data.lng
    if data.telefono    is not None: local.telefono    = data.telefono
    if data.descripcion is not None: local.descripcion = data.descripcion
    if data.foto_url    is not None: local.foto_url    = data.foto_url
    if data.activo      is not None: local.activo      = data.activo

    await db.commit()
    await db.refresh(local)
    return local
