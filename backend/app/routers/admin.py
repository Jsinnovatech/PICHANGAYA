from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from datetime import date, datetime, timezone, time, timedelta
import uuid
import logging
import json
import secrets

from app.core.database import get_db
from app.core.dependencies import require_admin
from app.models.reserva import Reserva, EstadoReservaEnum, TipoDocEnum
from app.models.pago import Pago, EstadoPagoEnum, MetodoPagoEnum
from app.models.user import User, RolEnum
from app.models.cancha import Cancha
from app.models.local import Local
from app.models.horario import HorarioDisponible
from app.models.bloqueo import BloqueoHorario
from app.models.comprobante import Comprobante, EstadoComprobanteEnum
from app.models.configuracion_pago import ConfiguracionPago
from app.notificaciones import notif_reserva_confirmada, notif_reserva_rechazada
from app.routers.websocket import notify_cliente, manager as ws_manager
from app.schemas.admin import (
    ReservaAdminResponse,
    PagoAdminResponse,
    ClienteAdminResponse,
    VerificarPagoRequest,
    CambiarEstadoReservaRequest,
    ReservaManualRequest,
    SlotAdminResponse,
    CanchaDisponibilidadResponse,
    CanchaAdminResponse,
    CanchaCreateRequest,
    CanchaUpdateRequest,
    TimerReservaResponse,
    FacturacionItemResponse,
    LocalAdminResponse,
    LocalCreateRequest,
    LocalUpdateRequest,
    BloqueoCreateRequest,
    BloqueoResponse,
    MediosPagoResponse,
    MediosPagoRequest,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["Admin"])


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

    # ── IDs de canchas de este admin (para filtrar stats) ────────
    admin_uuid = uuid.UUID(current_user["id"])
    cancha_ids_r = await db.execute(
        select(Cancha.id)
        .join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]

    # ── IDs de reservas del admin (para cruzar con pagos) ────────
    reserva_ids_r = await db.execute(
        select(Reserva.id).where(Reserva.cancha_id.in_(admin_cancha_ids))
    ) if admin_cancha_ids else None
    admin_reserva_ids = [row[0] for row in reserva_ids_r.all()] if reserva_ids_r else []

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
        db.execute(select(func.count(Reserva.id)).where(
            Reserva.fecha == hoy,
            Reserva.cancha_id.in_(admin_cancha_ids)
        )),
        db.execute(select(func.count(Reserva.id)).where(
            Reserva.estado == EstadoReservaEnum.pending,
            Reserva.cancha_id.in_(admin_cancha_ids)
        )),
        db.execute(select(func.sum(Pago.monto)).where(
            Pago.estado == EstadoPagoEnum.verificado,
            Pago.reserva_id.in_(admin_reserva_ids),
            func.date(Pago.created_at) == hoy,
        )),
        db.execute(select(func.count(User.id)).where(User.rol == RolEnum.cliente, User.activo == True)),
        db.execute(select(func.count(Pago.id)).where(
            Pago.estado == EstadoPagoEnum.pendiente,
            Pago.reserva_id.in_(admin_reserva_ids),
        )),
        db.execute(select(func.count(Reserva.id)).where(
            Reserva.cancha_id.in_(admin_cancha_ids)
        )),
        db.execute(select(func.sum(Pago.monto)).where(
            Pago.estado == EstadoPagoEnum.verificado,
            Pago.reserva_id.in_(admin_reserva_ids),
            func.date(Pago.created_at) >= primer_dia_mes,
            func.date(Pago.created_at) <= hoy,
        )),
        db.execute(
            select(Pago.metodo, func.count(Pago.id), func.sum(Pago.monto))
            .where(
                Pago.estado == EstadoPagoEnum.verificado,
                Pago.reserva_id.in_(admin_reserva_ids),
            )
            .group_by(Pago.metodo)
        ),
        db.execute(
            select(Reserva)
            .where(Reserva.cancha_id.in_(admin_cancha_ids))
            .order_by(Reserva.created_at.desc())
            .limit(20)
        ),
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
            Reserva.cancha_id.in_(admin_cancha_ids),
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
        admin_uuid = uuid.UUID(current_user["id"])

        # Paso 1: cancha_ids del admin (mismo patrón que el dashboard)
        cancha_ids_r = await db.execute(
            select(Cancha.id)
            .join(Local, Local.id == Cancha.local_id)
            .where(Local.admin_id == admin_uuid)
        )
        admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]
        logger.info(f"[admin_get_reservas] admin={admin_uuid} cancha_ids={admin_cancha_ids}")

        if not admin_cancha_ids:
            return []

        # Paso 2: reservas de esas canchas
        query = (
            select(Reserva)
            .where(Reserva.cancha_id.in_(admin_cancha_ids))
            .order_by(Reserva.created_at.desc())
        )

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
        logger.error("Error al consultar reservas en BD", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Error interno del servidor"
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

                # Detectar reservas manuales via campo notas JSON
            notas_data: dict = {}
            if reserva.notas:
                try:
                    notas_data = json.loads(reserva.notas) if isinstance(reserva.notas, str) else {}
                except Exception:
                    notas_data = {}
            es_manual = notas_data.get("manual", False) is True
            nombre_manual = notas_data.get("nombre_cliente")
            dni_manual = notas_data.get("dni_cliente")

            respuesta.append(ReservaAdminResponse(
                id=reserva.id,
                codigo=reserva.codigo,
                cliente_nombre=nombre_manual if es_manual and nombre_manual else (cliente.nombre if cliente else "Desconocido"),
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
                pago_id=pago.id if pago else None,
                es_manual=es_manual,
                dni_cliente=dni_manual if es_manual else (cliente.dni if cliente else None),
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
    admin_uuid = uuid.UUID(current_user["id"])

    # Verificar que la reserva pertenece a una cancha del local de este admin
    cancha_ids_r = await db.execute(
        select(Cancha.id).join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]

    result = await db.execute(select(Reserva).where(Reserva.id == reserva_id))
    reserva = result.scalar_one_or_none()

    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    if reserva.cancha_id not in admin_cancha_ids:
        raise HTTPException(status_code=403, detail="No tienes permiso sobre esta reserva")

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
    admin_uuid = uuid.UUID(current_user["id"])

    # Verificar que la reserva pertenece a una cancha del local de este admin
    cancha_ids_r = await db.execute(
        select(Cancha.id).join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]

    result = await db.execute(select(Reserva).where(Reserva.id == reserva_id))
    reserva = result.scalar_one_or_none()

    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    if reserva.cancha_id not in admin_cancha_ids:
        raise HTTPException(status_code=403, detail="No tienes permiso sobre esta reserva")

    # data.estado ya es EstadoReservaEnum — validado por Pydantic en el schema
    nuevo_estado = data.estado
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
    import asyncio

    admin_uuid = uuid.UUID(current_user["id"])
    cancha_ids_r = await db.execute(
        select(Cancha.id)
        .join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]

    reserva_ids_r = await db.execute(
        select(Reserva.id).where(Reserva.cancha_id.in_(admin_cancha_ids))
    ) if admin_cancha_ids else None
    admin_reserva_ids = [row[0] for row in reserva_ids_r.all()] if reserva_ids_r else []

    query = select(Pago).where(Pago.reserva_id.in_(admin_reserva_ids)).order_by(Pago.created_at.desc())
    if estado:
        try:
            estado_enum = EstadoPagoEnum(estado)
            query = query.where(Pago.estado == estado_enum)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Estado inválido: {estado}")

    result = await db.execute(query)
    pagos = result.scalars().all()

    if not pagos:
        return []

    # Batch queries — sin N+1
    cliente_ids  = list({p.cliente_id  for p in pagos})
    reserva_ids  = list({p.reserva_id  for p in pagos})
    clientes_r, reservas_r = await asyncio.gather(
        db.execute(select(User).where(User.id.in_(cliente_ids))),
        db.execute(select(Reserva).where(Reserva.id.in_(reserva_ids))),
    )
    clientes_map = {u.id: u for u in clientes_r.scalars().all()}
    reservas_map = {r.id: r for r in reservas_r.scalars().all()}

    return [
        PagoAdminResponse(
            id=pago.id,
            reserva_id=pago.reserva_id,
            reserva_codigo=reservas_map[pago.reserva_id].codigo if pago.reserva_id in reservas_map else None,
            cliente_nombre=clientes_map[pago.cliente_id].nombre if pago.cliente_id in clientes_map else None,
            cliente_celular=clientes_map[pago.cliente_id].celular if pago.cliente_id in clientes_map else None,
            monto=float(pago.monto),
            metodo=pago.metodo.value,
            estado=pago.estado.value,
            voucher_url=pago.voucher_url,
            fecha=str(pago.created_at.date()) if pago.created_at else None
        )
        for pago in pagos
    ]


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

    # Acción ya validada por VerificarPagoRequest.accion_valida (Pydantic)
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

    # ── Notificar vía WebSocket (en tiempo real, no crítico) ───
    if reserva:
        try:
            await notify_cliente(reserva.cliente_id, {"tipo": "pago_actualizado", "accion": data.accion})
        except Exception as e:
            logger.warning(f"WS notify_cliente falló (no crítico): {e}")
    try:
        await ws_manager.broadcast({"tipo": "pago_actualizado", "accion": data.accion})
    except Exception:
        pass

    return {"mensaje": mensaje, "pago_id": str(pago_id), "accion": data.accion}


# ══════════════════════════════════════════════
# CLIENTES
# ══════════════════════════════════════════════

@router.get("/clientes", response_model=List[ClienteAdminResponse])
async def admin_get_clientes(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    # Solo clientes que tienen reservas en los locales de este admin
    admin_uuid = uuid.UUID(current_user["id"])
    cancha_ids_r = await db.execute(
        select(Cancha.id)
        .join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]

    # IDs únicos de clientes con reservas en este local
    cliente_ids_r = await db.execute(
        select(Reserva.cliente_id).where(
            Reserva.cancha_id.in_(admin_cancha_ids)
        ).distinct()
    ) if admin_cancha_ids else None
    cliente_ids = [row[0] for row in cliente_ids_r.all()] if cliente_ids_r else []

    result = await db.execute(
        select(User).where(
            User.id.in_(cliente_ids),
            User.rol == RolEnum.cliente
        ).order_by(User.created_at.desc())
    )
    clientes = result.scalars().all()

    import asyncio

    # Batch: count reservas y sum pagos por cliente — sin N+1
    reservas_count_r, pagos_sum_r = await asyncio.gather(
        db.execute(
            select(Reserva.cliente_id, func.count(Reserva.id))
            .where(
                Reserva.cliente_id.in_(cliente_ids),
                Reserva.cancha_id.in_(admin_cancha_ids),
            )
            .group_by(Reserva.cliente_id)
        ),
        db.execute(
            select(Pago.cliente_id, func.sum(Pago.monto))
            .where(
                Pago.cliente_id.in_(cliente_ids),
                Pago.estado == EstadoPagoEnum.verificado,
            )
            .group_by(Pago.cliente_id)
        ),
    )
    reservas_count_map = {row[0]: row[1] for row in reservas_count_r.all()}
    pagos_sum_map      = {row[0]: float(row[1] or 0) for row in pagos_sum_r.all()}

    return [
        ClienteAdminResponse(
            id=cliente.id,
            nombre=cliente.nombre,
            celular=cliente.celular,
            dni=cliente.dni,
            activo=cliente.activo,
            total_reservas=reservas_count_map.get(cliente.id, 0),
            total_gastado=pagos_sum_map.get(cliente.id, 0.0),
        )
        for cliente in clientes
    ]


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

@router.get("/canchas", response_model=List[CanchaAdminResponse])
async def admin_get_canchas(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    # Solo las canchas de los locales que pertenecen a este admin
    result = await db.execute(
        select(Cancha, Local.nombre.label("local_nombre"))
        .join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == uuid.UUID(current_user["id"]))
        .order_by(Cancha.created_at.desc())
    )
    filas = result.all()
    if not filas:
        return []

    return [
        CanchaAdminResponse(
            id=c.id, local_id=c.local_id,
            local_nombre=local_nombre,
            nombre=c.nombre, descripcion=c.descripcion,
            capacidad=c.capacidad, precio_hora=float(c.precio_hora),
            precio_dia=float(c.precio_dia) if c.precio_dia is not None else None,
            precio_noche=float(c.precio_noche) if c.precio_noche is not None else None,
            superficie=c.superficie, activa=c.activa
        )
        for c, local_nombre in filas
    ]


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
    await db.flush()  # obtener el ID de la cancha antes del commit

    # Auto-crear horarios por defecto: lunes a domingo, 08:00 – 22:00
    from datetime import time as time_type
    for dia in range(7):  # 0=Lunes ... 6=Domingo
        horario = HorarioDisponible(
            id=uuid.uuid4(),
            cancha_id=cancha.id,
            dia_semana=dia,
            hora_inicio=time_type(7, 0),
            hora_fin=time_type(0, 0),
            precio_override=None,
            activo=True
        )
        db.add(horario)

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

    # Guardar precio_dia / precio_noche directo en la columna de Cancha
    if data.precio_dia is not None:
        cancha.precio_dia = data.precio_dia
    if data.precio_noche is not None:
        cancha.precio_noche = data.precio_noche

    # También propagar a precio_override en HorarioDisponible (si existen)
    if data.precio_dia is not None or data.precio_noche is not None:
        horarios_r = await db.execute(
            select(HorarioDisponible).where(HorarioDisponible.cancha_id == cancha.id)
        )
        horarios = horarios_r.scalars().all()
        for h in horarios:
            if data.precio_dia is not None and h.hora_inicio.hour < 18:
                h.precio_override = data.precio_dia
            if data.precio_noche is not None and h.hora_inicio.hour >= 18:
                h.precio_override = data.precio_noche

    await db.commit()
    return {"mensaje": "Cancha actualizada"}


# ══════════════════════════════════════════════
# TIMERS
# ══════════════════════════════════════════════

@router.get("/timers/hoy", response_model=List[TimerReservaResponse])
async def admin_timers_hoy(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    admin_uuid = uuid.UUID(current_user["id"])
    cancha_ids_r = await db.execute(
        select(Cancha.id)
        .join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]

    LIMA_TZ = timezone(timedelta(hours=-5))
    hoy = datetime.now(LIMA_TZ).date()
    result = await db.execute(
        select(Reserva).where(
            Reserva.fecha == hoy,
            Reserva.estado.in_([EstadoReservaEnum.confirmed, EstadoReservaEnum.active]),
            Reserva.cancha_id.in_(admin_cancha_ids),
        ).order_by(Reserva.hora_inicio)
    )
    reservas = result.scalars().all()

    if not reservas:
        return []

    import asyncio

    # Batch queries — sin N+1
    cliente_ids = list({r.cliente_id for r in reservas})
    cancha_ids  = list({r.cancha_id  for r in reservas})
    clientes_r, canchas_r = await asyncio.gather(
        db.execute(select(User).where(User.id.in_(cliente_ids))),
        db.execute(select(Cancha).where(Cancha.id.in_(cancha_ids))),
    )
    clientes_map = {u.id: u for u in clientes_r.scalars().all()}
    canchas_map  = {c.id: c for c in canchas_r.scalars().all()}

    return [
        TimerReservaResponse(
            id=r.id, codigo=r.codigo,
            cliente_nombre=clientes_map[r.cliente_id].nombre if r.cliente_id in clientes_map else "—",
            cliente_celular=clientes_map[r.cliente_id].celular if r.cliente_id in clientes_map else "",
            cancha_nombre=canchas_map[r.cancha_id].nombre if r.cancha_id in canchas_map else None,
            fecha=r.fecha,
            hora_inicio=str(r.hora_inicio)[:5],
            hora_fin=str(r.hora_fin)[:5],
            estado=r.estado.value,
            precio_total=float(r.precio_total)
        )
        for r in reservas
    ]


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

@router.get("/facturacion", response_model=List[FacturacionItemResponse])
async def admin_get_facturacion(
    tipo_doc: Optional[str] = None,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    admin_uuid = uuid.UUID(current_user["id"])
    cancha_ids_r = await db.execute(
        select(Cancha.id)
        .join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]
    reserva_ids_r = await db.execute(
        select(Reserva.id).where(Reserva.cancha_id.in_(admin_cancha_ids))
    ) if admin_cancha_ids else None
    admin_reserva_ids = [row[0] for row in reserva_ids_r.all()] if reserva_ids_r else []

    query = (
        select(Pago)
        .where(Pago.estado == EstadoPagoEnum.verificado, Pago.reserva_id.in_(admin_reserva_ids))
        .order_by(Pago.created_at.desc())
    )
    result = await db.execute(query)
    pagos = result.scalars().all()

    if not pagos:
        return []

    import asyncio

    # Batch queries — sin N+1
    reserva_ids = list({p.reserva_id for p in pagos})
    cliente_ids = list({p.cliente_id for p in pagos})

    reservas_r, clientes_r, comprobantes_r = await asyncio.gather(
        db.execute(select(Reserva).where(Reserva.id.in_(reserva_ids))),
        db.execute(select(User).where(User.id.in_(cliente_ids))),
        db.execute(select(Comprobante).where(Comprobante.reserva_id.in_(reserva_ids))),
    )
    reservas_map     = {r.id: r for r in reservas_r.scalars().all()}
    clientes_map     = {u.id: u for u in clientes_r.scalars().all()}
    comprobantes_map = {c.reserva_id: c for c in comprobantes_r.scalars().all()}

    cancha_ids = list({r.cancha_id for r in reservas_map.values()})
    canchas_map = {
        c.id: c for c in (await db.execute(
            select(Cancha).where(Cancha.id.in_(cancha_ids))
        )).scalars().all()
    } if cancha_ids else {}

    respuesta = []
    for pago in pagos:
        reserva = reservas_map.get(pago.reserva_id)
        if not reserva:
            continue
        if tipo_doc and (reserva.tipo_doc is None or reserva.tipo_doc.value != tipo_doc):
            continue
        cliente = clientes_map.get(pago.cliente_id)
        cancha  = canchas_map.get(reserva.cancha_id)
        comp    = comprobantes_map.get(reserva.id)

        # Detectar reservas manuales via campo notas JSON
        notas_data_f: dict = {}
        if reserva.notas:
            try:
                notas_data_f = json.loads(reserva.notas) if isinstance(reserva.notas, str) else {}
            except Exception:
                notas_data_f = {}
        es_manual_f = notas_data_f.get("manual", False) is True
        nombre_manual_f = notas_data_f.get("nombre_cliente")
        dni_manual_f = notas_data_f.get("dni_cliente")

        respuesta.append(FacturacionItemResponse(
            reserva_id=reserva.id, codigo=reserva.codigo,
            cliente_nombre=nombre_manual_f if es_manual_f and nombre_manual_f else (cliente.nombre if cliente else "—"),
            cliente_celular=cliente.celular if cliente else "",
            cancha_nombre=cancha.nombre if cancha else None,
            fecha=reserva.fecha, monto=float(pago.monto),
            metodo_pago=pago.metodo.value,
            tipo_doc=reserva.tipo_doc.value if reserva.tipo_doc else None,
            ruc_factura=reserva.ruc_factura,
            razon_social=reserva.razon_social,
            comprobante_estado=comp.estado.value if comp else None,
            comprobante_serie=comp.serie if comp else None,
            comprobante_numero=comp.numero if comp else None,
            pdf_url=comp.pdf_url if comp else None,
            fecha_pago=str(pago.created_at.date()) if pago.created_at else None,
            es_manual=es_manual_f,
            dni_cliente=dni_manual_f if es_manual_f else (cliente.dni if cliente else None),
        ))
    return respuesta


@router.get("/facturacion/stats")
async def admin_facturacion_stats(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    admin_uuid = uuid.UUID(current_user["id"])
    cancha_ids_r = await db.execute(
        select(Cancha.id)
        .join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]
    reserva_ids_r = await db.execute(
        select(Reserva.id).where(Reserva.cancha_id.in_(admin_cancha_ids))
    ) if admin_cancha_ids else None
    admin_reserva_ids = [row[0] for row in reserva_ids_r.all()] if reserva_ids_r else []

    import asyncio

    pagos_verif_r, reservas_tipo_r = await asyncio.gather(
        db.execute(
            select(Pago.monto).where(
                Pago.estado == EstadoPagoEnum.verificado,
                Pago.reserva_id.in_(admin_reserva_ids),
            )
        ),
        db.execute(
            select(Reserva.tipo_doc).where(
                Reserva.id.in_(admin_reserva_ids),
                Reserva.estado != EstadoReservaEnum.canceled,
            )
        ),
    )
    total_ingresos = sum(float(m) for m in pagos_verif_r.scalars().all())

    boletas = facturas = sin_tipo = 0
    for tipo_doc_val in reservas_tipo_r.scalars().all():
        if tipo_doc_val == TipoDocEnum.boleta:   boletas  += 1
        elif tipo_doc_val == TipoDocEnum.factura: facturas += 1
        else:                                     sin_tipo += 1

    hoy = datetime.now(timezone.utc).date()
    primer_dia_mes = hoy.replace(day=1)
    ingresos_mes = float((await db.execute(
        select(func.sum(Pago.monto)).where(
            Pago.estado == EstadoPagoEnum.verificado,
            Pago.reserva_id.in_(admin_reserva_ids),
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


# ══════════════════════════════════════════════
# RESERVA MANUAL
# ══════════════════════════════════════════════

@router.get("/disponibilidad-canchas", response_model=List[CanchaDisponibilidadResponse])
async def get_disponibilidad_canchas(
    fecha: date = Query(...),
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Devuelve todas las canchas del local del admin con sus slots del día."""
    admin_uuid = uuid.UUID(current_user["id"])
    dia_semana = fecha.weekday()

    # Canchas activas del local del admin
    canchas_r = await db.execute(
        select(Cancha)
        .join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid, Cancha.activa == True)
        .order_by(Cancha.nombre)
    )
    canchas = canchas_r.scalars().all()

    def _t_min(t) -> int:
        if t.hour == 0 and t.minute == 0:
            return 1440
        return t.hour * 60 + t.minute

    resultado = []
    for cancha in canchas:
        # Horarios del día para esta cancha
        horarios_r = await db.execute(
            select(HorarioDisponible).where(
                HorarioDisponible.cancha_id == cancha.id,
                HorarioDisponible.dia_semana == dia_semana,
                HorarioDisponible.activo == True
            ).order_by(HorarioDisponible.hora_inicio)
        )
        horarios = horarios_r.scalars().all()
        if not horarios:
            continue

        # Reservas activas del día
        reservas_r = await db.execute(
            select(Reserva.hora_inicio, Reserva.hora_fin).where(
                Reserva.cancha_id == cancha.id,
                Reserva.fecha == fecha,
                Reserva.estado.in_([
                    EstadoReservaEnum.pending,
                    EstadoReservaEnum.confirmed,
                    EstadoReservaEnum.active
                ])
            )
        )
        reservas_activas = reservas_r.fetchall()

        # Bloqueos manuales del día
        bloqueos_r = await db.execute(
            select(BloqueoHorario.hora_inicio, BloqueoHorario.hora_fin).where(
                BloqueoHorario.cancha_id == cancha.id,
                BloqueoHorario.fecha == fecha,
            )
        )
        bloqueos_activos = bloqueos_r.fetchall()

        def _ocupado(s_ini, s_fin) -> bool:
            s0, s1 = _t_min(s_ini), _t_min(s_fin)
            for r_ini, r_fin in reservas_activas:
                if _t_min(r_ini) < s1 and _t_min(r_fin) > s0:
                    return True
            for b_ini, b_fin in bloqueos_activos:
                if _t_min(b_ini) < s1 and _t_min(b_fin) > s0:
                    return True
            return False

        precio_base = float(cancha.precio_hora)
        slots = []
        for horario in horarios:
            precio = float(horario.precio_override) if horario.precio_override else precio_base
            ini_min = horario.hora_inicio.hour * 60 + horario.hora_inicio.minute
            fin_h, fin_m = horario.hora_fin.hour, horario.hora_fin.minute
            fin_min = 1440 if (fin_h == 0 and fin_m == 0) else fin_h * 60 + fin_m

            current = ini_min
            while current + 60 <= fin_min:
                next_min = current + 60
                slot_ini = time(current // 60, current % 60)
                slot_fin = time(0, 0) if next_min == 1440 else time(next_min // 60, next_min % 60)
                slots.append(SlotAdminResponse(
                    hora_inicio=f"{current // 60:02d}:{current % 60:02d}",
                    hora_fin=f"{next_min % 1440 // 60:02d}:{next_min % 1440 % 60:02d}",
                    disponible=not _ocupado(slot_ini, slot_fin),
                    precio=precio
                ))
                current += 60

        # Calcular precio día (06:00-18:00) y noche (18:00-00:00) como referencia
        precios_slots = [float(h.precio_override) if h.precio_override else precio_base for h in horarios]
        precios_dia    = [float(h.precio_override) if h.precio_override else precio_base
                          for h in horarios if h.hora_inicio.hour < 18]
        precios_noche  = [float(h.precio_override) if h.precio_override else precio_base
                          for h in horarios if h.hora_inicio.hour >= 18]

        resultado.append(CanchaDisponibilidadResponse(
            cancha_id=cancha.id,
            cancha_nombre=cancha.nombre,
            tipo_piso=cancha.tipo_piso if hasattr(cancha, 'tipo_piso') else None,
            precio_hora=precio_base,
            precio_dia=min(precios_dia) if precios_dia else None,
            precio_noche=min(precios_noche) if precios_noche else None,
            slots=slots
        ))

    return resultado


@router.post("/reservas/manual", status_code=201)
async def crear_reserva_manual(
    data: ReservaManualRequest,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Admin crea una reserva presencial en nombre de un cliente walk-in."""
    admin_uuid = uuid.UUID(current_user["id"])

    # Verificar que la cancha pertenece al local del admin
    cancha_r = await db.execute(
        select(Cancha)
        .join(Local, Local.id == Cancha.local_id)
        .where(Cancha.id == data.cancha_id, Local.admin_id == admin_uuid, Cancha.activa == True)
    )
    cancha = cancha_r.scalar_one_or_none()
    if not cancha:
        raise HTTPException(status_code=404, detail="Cancha no encontrada o no pertenece a tu local")

    # Validaciones de factura, hora y DNI ya resueltas por ReservaManualRequest (Pydantic)
    es_factura = data.tipo_doc == TipoDocEnum.factura

    # Parsear horas (ya validadas en formato HH:MM por el schema)
    def _parse_time(s: str) -> time:
        h, m = s.split(":")
        return time(int(h), int(m))

    hora_inicio_t = _parse_time(data.hora_inicio)
    hora_fin_t    = _parse_time(data.hora_fin)

    def _t_min(t) -> int:
        if t.hour == 0 and t.minute == 0:
            return 1440
        return t.hour * 60 + t.minute

    new_start = _t_min(hora_inicio_t)
    new_end   = _t_min(hora_fin_t)

    # Verificar slot libre
    reservas_r = await db.execute(
        select(Reserva).where(
            Reserva.cancha_id == data.cancha_id,
            Reserva.fecha == data.fecha,
            Reserva.estado.in_([EstadoReservaEnum.pending, EstadoReservaEnum.confirmed, EstadoReservaEnum.active])
        )
    )
    for r in reservas_r.scalars().all():
        if _t_min(r.hora_inicio) < new_end and _t_min(r.hora_fin) > new_start:
            raise HTTPException(status_code=409, detail=f"El horario {data.hora_inicio}–{data.hora_fin} ya está reservado")

    precio_total = round(float(cancha.precio_hora) * (new_end - new_start) / 60, 2)

    # Guardar datos del cliente walk-in en notas (JSON)
    notas_data = json.dumps({
        "manual": True,
        "nombre_cliente": data.nombre_cliente.strip(),
        "dni_cliente": data.dni_cliente.strip()
    }, ensure_ascii=False)

    nueva_reserva = Reserva(
        id=uuid.uuid4(),
        codigo=f"MAN-{secrets.token_hex(3).upper()}",
        cliente_id=admin_uuid,   # admin como titular
        cancha_id=data.cancha_id,
        fecha=data.fecha,
        hora_inicio=hora_inicio_t,
        hora_fin=hora_fin_t,
        precio_total=precio_total,
        estado=EstadoReservaEnum.confirmed,   # confirmada de inmediato
        tipo_doc=data.tipo_doc,               # ya es TipoDocEnum desde el schema
        ruc_factura=data.ruc_factura.strip() if es_factura and data.ruc_factura else None,
        razon_social=data.razon_social.strip() if es_factura and data.razon_social else None,
        notas=notas_data
    )
    db.add(nueva_reserva)

    LIMA_TZ = timezone(timedelta(hours=-5))
    nuevo_pago = Pago(
        id=uuid.uuid4(),
        reserva_id=nueva_reserva.id,
        cliente_id=admin_uuid,
        monto=precio_total,
        metodo=data.metodo_pago,              # ya es MetodoPagoEnum desde el schema
        estado=EstadoPagoEnum.verificado,     # pagado en el momento
        voucher_url=None,
        comprobante_ext=None,
        verificado_por=admin_uuid,
        verificado_at=datetime.now(LIMA_TZ)
    )
    db.add(nuevo_pago)

    await db.commit()
    await db.refresh(nueva_reserva)

    return {
        "reserva_id": str(nueva_reserva.id),
        "codigo": nueva_reserva.codigo,
        "precio_total": precio_total,
        "mensaje": "Reserva manual creada exitosamente"
    }


# ══════════════════════════════════════════════
# BLOQUEOS DE HORARIO
# ══════════════════════════════════════════════

@router.get("/bloqueos", response_model=List[BloqueoResponse])
async def admin_get_bloqueos(
    cancha_id: Optional[uuid.UUID] = None,
    fecha: Optional[date] = None,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Lista los bloqueos del admin, filtrables por cancha y/o fecha."""
    admin_uuid = uuid.UUID(current_user["id"])

    cancha_ids_r = await db.execute(
        select(Cancha.id).join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]
    if not admin_cancha_ids:
        return []

    query = select(BloqueoHorario).where(BloqueoHorario.cancha_id.in_(admin_cancha_ids))
    if cancha_id:
        query = query.where(BloqueoHorario.cancha_id == cancha_id)
    if fecha:
        query = query.where(BloqueoHorario.fecha == fecha)

    bloqueos = (await db.execute(query.order_by(BloqueoHorario.fecha, BloqueoHorario.hora_inicio))).scalars().all()

    # Nombres de canchas en batch
    ids_usados = list({b.cancha_id for b in bloqueos})
    canchas_map = {
        c.id: c.nombre for c in (await db.execute(
            select(Cancha).where(Cancha.id.in_(ids_usados))
        )).scalars().all()
    } if ids_usados else {}

    return [
        BloqueoResponse(
            id=b.id,
            cancha_id=b.cancha_id,
            cancha_nombre=canchas_map.get(b.cancha_id),
            fecha=b.fecha,
            hora_inicio=str(b.hora_inicio)[:5],
            hora_fin=str(b.hora_fin)[:5],
            motivo=b.motivo,
        )
        for b in bloqueos
    ]


@router.post("/bloqueos", response_model=BloqueoResponse, status_code=201)
async def admin_crear_bloqueo(
    data: BloqueoCreateRequest,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Bloquea un rango horario de una cancha (mantenimiento, evento privado, etc.)."""
    admin_uuid = uuid.UUID(current_user["id"])

    # Verificar pertenencia de la cancha
    cancha_r = await db.execute(
        select(Cancha).join(Local, Local.id == Cancha.local_id)
        .where(Cancha.id == data.cancha_id, Local.admin_id == admin_uuid)
    )
    cancha = cancha_r.scalar_one_or_none()
    if not cancha:
        raise HTTPException(status_code=404, detail="Cancha no encontrada o no te pertenece")

    # Parsear horas
    def _parse(s: str) -> time:
        try:
            h, m = s.split(":")[:2]
            return time(int(h), int(m))
        except Exception:
            raise HTTPException(status_code=400, detail=f"Hora inválida: {s}")

    hora_inicio_t = _parse(data.hora_inicio)
    hora_fin_t    = _parse(data.hora_fin)

    # Verificar que no haya reservas activas en ese rango
    def _t_min(t) -> int:
        return 1440 if (t.hour == 0 and t.minute == 0) else t.hour * 60 + t.minute

    new_start = _t_min(hora_inicio_t)
    new_end   = _t_min(hora_fin_t)

    reservas_conflicto = (await db.execute(
        select(Reserva).where(
            Reserva.cancha_id == data.cancha_id,
            Reserva.fecha == data.fecha,
            Reserva.estado.in_([EstadoReservaEnum.pending, EstadoReservaEnum.confirmed, EstadoReservaEnum.active])
        )
    )).scalars().all()

    conflictos = [r for r in reservas_conflicto
                  if _t_min(r.hora_inicio) < new_end and _t_min(r.hora_fin) > new_start]
    if conflictos:
        raise HTTPException(
            status_code=409,
            detail=f"Hay {len(conflictos)} reserva(s) activa(s) en ese rango. Cancélalas primero."
        )

    bloqueo = BloqueoHorario(
        id=uuid.uuid4(),
        cancha_id=data.cancha_id,
        fecha=data.fecha,
        hora_inicio=hora_inicio_t,
        hora_fin=hora_fin_t,
        motivo=data.motivo.strip() if data.motivo else None,
        creado_por=admin_uuid,
    )
    db.add(bloqueo)
    await db.commit()
    await db.refresh(bloqueo)

    return BloqueoResponse(
        id=bloqueo.id,
        cancha_id=bloqueo.cancha_id,
        cancha_nombre=cancha.nombre,
        fecha=bloqueo.fecha,
        hora_inicio=str(bloqueo.hora_inicio)[:5],
        hora_fin=str(bloqueo.hora_fin)[:5],
        motivo=bloqueo.motivo,
    )


@router.delete("/bloqueos/{bloqueo_id}", status_code=204)
async def admin_eliminar_bloqueo(
    bloqueo_id: uuid.UUID,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Elimina un bloqueo de horario."""
    admin_uuid = uuid.UUID(current_user["id"])

    bloqueo_r = await db.execute(select(BloqueoHorario).where(BloqueoHorario.id == bloqueo_id))
    bloqueo = bloqueo_r.scalar_one_or_none()
    if not bloqueo:
        raise HTTPException(status_code=404, detail="Bloqueo no encontrado")

    # Verificar pertenencia
    cancha_ids_r = await db.execute(
        select(Cancha.id).join(Local, Local.id == Cancha.local_id)
        .where(Local.admin_id == admin_uuid)
    )
    admin_cancha_ids = [row[0] for row in cancha_ids_r.all()]
    if bloqueo.cancha_id not in admin_cancha_ids:
        raise HTTPException(status_code=403, detail="No tienes permiso sobre este bloqueo")

    await db.delete(bloqueo)
    await db.commit()


# ══════════════════════════════════════════════
# MEDIOS DE PAGO — configuración por admin
# ══════════════════════════════════════════════

@router.get("/medios-pago", response_model=MediosPagoResponse)
async def admin_get_medios_pago(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Devuelve la configuración de medios de pago del admin autenticado."""
    admin_uuid = uuid.UUID(current_user["id"])
    result = await db.execute(
        select(ConfiguracionPago).where(ConfiguracionPago.admin_id == admin_uuid)
    )
    config = result.scalar_one_or_none()
    if not config:
        return MediosPagoResponse()
    return MediosPagoResponse(
        yape_numero=config.yape_numero,
        qr_imagen_base64=config.qr_imagen_base64,
        cuenta_bcp=config.cuenta_bcp,
        cuenta_bbva=config.cuenta_bbva,
    )


@router.put("/medios-pago", response_model=MediosPagoResponse)
async def admin_put_medios_pago(
    data: MediosPagoRequest,
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Crea o actualiza la configuración de medios de pago del admin."""
    admin_uuid = uuid.UUID(current_user["id"])
    result = await db.execute(
        select(ConfiguracionPago).where(ConfiguracionPago.admin_id == admin_uuid)
    )
    config = result.scalar_one_or_none()

    if config is None:
        config = ConfiguracionPago(admin_id=admin_uuid)
        db.add(config)

    config.yape_numero = data.yape_numero
    config.cuenta_bcp = data.cuenta_bcp
    config.cuenta_bbva = data.cuenta_bbva
    # Solo actualizar QR si se envía un valor (None = sin cambios, "" = borrar)
    if data.qr_imagen_base64 is not None:
        config.qr_imagen_base64 = data.qr_imagen_base64 if data.qr_imagen_base64 else None

    await db.commit()
    await db.refresh(config)

    return MediosPagoResponse(
        yape_numero=config.yape_numero,
        qr_imagen_base64=config.qr_imagen_base64,
        cuenta_bcp=config.cuenta_bcp,
        cuenta_bbva=config.cuenta_bbva,
    )
