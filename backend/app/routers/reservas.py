from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.exc import IntegrityError
from typing import List
from datetime import date as date_type, time as time_type
import uuid
import logging

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.reserva import Reserva, EstadoReservaEnum, TipoDocEnum
from app.models.pago import Pago, MetodoPagoEnum, EstadoPagoEnum
from app.models.cancha import Cancha
from app.models.local import Local
from app.models.user import User
from app.models.comprobante import Comprobante
from app.schemas.reservas import ReservaCreateRequest, ReservaResponse, MiReservaResponse
from app.notificaciones import notif_reserva_nueva, notif_reserva_cancelada_por_cliente
from app.routers.websocket import manager as ws_manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/reservas", tags=["Reservas"])


def str_a_time(hora_str: str) -> time_type:
    try:
        partes = hora_str.split(":")
        if len(partes) < 2:
            raise ValueError
        h, m = int(partes[0]), int(partes[1])
        # 24:00 = medianoche = 00:00 (fin del slot nocturno 23:00-24:00)
        if h == 24 and m == 0:
            return time_type(0, 0)
        return time_type(h, m)
    except (ValueError, IndexError):
        raise HTTPException(status_code=400, detail=f"Hora inválida: '{hora_str}'. Use formato HH:MM")


def generar_codigo_reserva() -> str:
    """Código único basado en UUID — sin race condition."""
    import secrets
    return f"RES-{secrets.token_hex(3).upper()}"


@router.post("/", response_model=ReservaResponse, status_code=201)
async def crear_reserva(
    data: ReservaCreateRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # ── Paso 1: Verificar cancha ──────────────────────────────
    cancha_result = await db.execute(
        select(Cancha).where(Cancha.id == data.cancha_id, Cancha.activa == True)
    )
    cancha = cancha_result.scalar_one_or_none()
    if not cancha:
        raise HTTPException(status_code=404, detail="Cancha no encontrada o inactiva")

    # ── Paso 2: Verificar slot libre (range overlap) ─────────
    hora_inicio_time = str_a_time(data.hora_inicio)
    hora_fin_time = str_a_time(data.hora_fin)

    def _t_min(t) -> int:
        """Convierte time a minutos. Medianoche (00:00) = 1440 (fin del día)."""
        if t.hour == 0 and t.minute == 0:
            return 1440
        return t.hour * 60 + t.minute

    reservas_existentes = (await db.execute(
        select(Reserva).where(
            Reserva.cancha_id == data.cancha_id,
            Reserva.fecha == data.fecha,
            Reserva.estado.in_([
                EstadoReservaEnum.pending,
                EstadoReservaEnum.confirmed,
                EstadoReservaEnum.active
            ])
        )
    )).scalars().all()

    new_start = _t_min(hora_inicio_time)
    new_end   = _t_min(hora_fin_time)
    for r in reservas_existentes:
        r_start = _t_min(r.hora_inicio)
        r_end   = _t_min(r.hora_fin)
        if r_start < new_end and r_end > new_start:
            raise HTTPException(
                status_code=409,
                detail=f"El horario {data.hora_inicio}–{data.hora_fin} del {data.fecha} ya está reservado"
            )

    # ── Paso 3: Datos del local ───────────────────────────────
    local_result = await db.execute(
        select(Local).where(Local.id == cancha.local_id)
    )
    local = local_result.scalar_one_or_none()

    # ── Paso 4: Código de reserva ─────────────────────────────
    codigo = generar_codigo_reserva()

    # ── Paso 4b: Validar datos de factura ────────────────────
    es_factura = data.tipo_doc == "factura"
    if es_factura:
        ruc = (data.ruc_factura or "").strip()
        rs  = (data.razon_social or "").strip()
        if len(ruc) != 11 or not ruc.isdigit():
            raise HTTPException(status_code=400, detail="RUC inválido: debe tener 11 dígitos")
        if not rs:
            raise HTTPException(status_code=400, detail="La razón social es obligatoria para facturas")

    # ── Paso 5: Crear reserva ─────────────────────────────────
    # Precio según horario: día (00:00–17:59) → precio_dia, noche (18:00–23:59) → precio_noche
    if hora_inicio_time.hour < 18:
        precio_por_hora = float(cancha.precio_dia or cancha.precio_hora)
    else:
        precio_por_hora = float(cancha.precio_noche or cancha.precio_hora)
    precio_calculado = round(precio_por_hora * (new_end - new_start) / 60, 2)

    nueva_reserva = Reserva(
        id=uuid.uuid4(),
        codigo=codigo,
        cliente_id=uuid.UUID(current_user["id"]),
        cancha_id=data.cancha_id,
        fecha=data.fecha,
        hora_inicio=hora_inicio_time,
        hora_fin=hora_fin_time,
        precio_total=precio_calculado,
        estado=EstadoReservaEnum.pending,
        tipo_doc=TipoDocEnum.factura if es_factura else TipoDocEnum.boleta,
        ruc_factura=data.ruc_factura.strip() if es_factura and data.ruc_factura else None,
        razon_social=data.razon_social.strip() if es_factura and data.razon_social else None,
        notas=None
    )
    db.add(nueva_reserva)

    # ── Paso 6: Crear pago ────────────────────────────────────
    nuevo_pago = Pago(
        id=uuid.uuid4(),
        reserva_id=nueva_reserva.id,
        cliente_id=uuid.UUID(current_user["id"]),
        monto=nueva_reserva.precio_total,  # total real (horas × precio_hora)
        metodo=MetodoPagoEnum(data.metodo_pago),
        estado=EstadoPagoEnum.pendiente,
        voucher_url=None,
        comprobante_ext=None
    )
    db.add(nuevo_pago)

    # ── Paso 7: Flush con manejo de conflicto ─────────────────
    try:
        await db.flush()
    except IntegrityError as exc:
        await db.rollback()
        # Puede ser conflicto de slot o colisión de código (muy raro)
        if "uq_reserva_slot" in str(exc.orig):
            raise HTTPException(
                status_code=409,
                detail=f"El horario {data.hora_inicio} del {data.fecha} ya está reservado"
            )
        # Colisión de código → reintentar con nuevo código
        nueva_reserva.codigo = generar_codigo_reserva()
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            raise HTTPException(status_code=409, detail="Error al generar reserva, intente de nuevo")

    # ── Paso 8: Commit ────────────────────────────────────────
    await db.commit()
    await db.refresh(nueva_reserva)

    # ── Paso 9: Notificar al admin del local (no crítico) ─────
    try:
        if local and local.admin_id:
            admin_result = await db.execute(
                select(User).where(
                    User.id == local.admin_id,
                    User.activo == True
                )
            )
            admin = admin_result.scalar_one_or_none()
            if admin:
                cliente_result = await db.execute(
                    select(User).where(User.id == uuid.UUID(current_user["id"]))
                )
                cliente = cliente_result.scalar_one_or_none()
                cliente_nombre = cliente.nombre if cliente else "Cliente"
                await notif_reserva_nueva(
                    db=db,
                    admin_id=admin.id,
                    cliente_nombre=cliente_nombre,
                    cancha_nombre=cancha.nombre,
                    fecha=str(data.fecha),
                    hora=data.hora_inicio,
                    codigo=codigo
                )
                await db.commit()
    except Exception as e:
        logger.warning(f"Notificación de nueva reserva no enviada: {e}")

    # ── Broadcast WS al dashboard del admin (no crítico) ─────
    try:
        await ws_manager.broadcast({"tipo": "nueva_reserva"})
    except Exception:
        pass

    return ReservaResponse(
        id=nueva_reserva.id,
        codigo=nueva_reserva.codigo,
        cancha_nombre=cancha.nombre,
        local_nombre=local.nombre if local else None,
        fecha=nueva_reserva.fecha,
        hora_inicio=str(nueva_reserva.hora_inicio)[:5],
        hora_fin=str(nueva_reserva.hora_fin)[:5],
        precio_total=float(nueva_reserva.precio_total),
        estado=nueva_reserva.estado.value,
        metodo_pago=nuevo_pago.metodo.value,
        pago_id=nuevo_pago.id
    )


@router.get("/mis-reservas", response_model=List[MiReservaResponse])
async def mis_reservas(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    import asyncio

    result = await db.execute(
        select(Reserva)
        .where(Reserva.cliente_id == uuid.UUID(current_user["id"]))
        .order_by(Reserva.created_at.desc())
    )
    reservas = result.scalars().all()

    if not reservas:
        return []

    # Batch queries en paralelo — sin N+1
    reserva_ids = [r.id for r in reservas]
    cancha_ids  = list({r.cancha_id for r in reservas})

    canchas_rows, pagos_rows, comprobantes_rows = await asyncio.gather(
        db.execute(select(Cancha).where(Cancha.id.in_(cancha_ids))),
        db.execute(select(Pago).where(Pago.reserva_id.in_(reserva_ids))),
        db.execute(select(Comprobante).where(Comprobante.reserva_id.in_(reserva_ids))),
    )
    canchas_map      = {c.id: c for c in canchas_rows.scalars().all()}
    pagos_map        = {p.reserva_id: p for p in pagos_rows.scalars().all()}
    comprobantes_map = {c.reserva_id: c for c in comprobantes_rows.scalars().all()}

    # Batch de locales a partir de las canchas encontradas
    local_ids   = list({c.local_id for c in canchas_map.values()})
    locales_map = {
        l.id: l for l in (await db.execute(
            select(Local).where(Local.id.in_(local_ids))
        )).scalars().all()
    } if local_ids else {}

    respuesta = []
    for reserva in reservas:
        cancha       = canchas_map.get(reserva.cancha_id)
        local        = locales_map.get(cancha.local_id) if cancha else None
        pago         = pagos_map.get(reserva.id)
        comprobante  = comprobantes_map.get(reserva.id)

        # serie_fact: "B001-00001" (serie-numero del comprobante emitido)
        serie_fact = None
        if comprobante and comprobante.serie and comprobante.numero:
            serie_fact = f"{comprobante.serie}-{str(comprobante.numero).zfill(5)}"

        respuesta.append(MiReservaResponse(
            id=reserva.id,
            codigo=reserva.codigo,
            cancha_nombre=cancha.nombre if cancha else None,
            local_nombre=local.nombre if local else None,
            fecha=reserva.fecha,
            hora_inicio=str(reserva.hora_inicio)[:5],
            hora_fin=str(reserva.hora_fin)[:5],
            precio_total=float(reserva.precio_total),
            estado=reserva.estado.value,
            tipo_doc=reserva.tipo_doc.value if reserva.tipo_doc else None,
            metodo_pago=pago.metodo.value if pago else None,
            serie_fact=serie_fact
        ))

    return respuesta


@router.patch("/{reserva_id}/cancelar")
async def cancelar_reserva(
    reserva_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # ── Paso 1: Buscar la reserva del cliente ─────────────────
    result = await db.execute(
        select(Reserva).where(
            Reserva.id == reserva_id,
            Reserva.cliente_id == uuid.UUID(current_user["id"])
        )
    )
    reserva = result.scalar_one_or_none()

    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    # ── Paso 2: Solo se pueden cancelar reservas pendientes ───
    if reserva.estado not in [EstadoReservaEnum.pending]:
        raise HTTPException(
            status_code=400,
            detail=f"Solo puedes cancelar reservas pendientes. Estado actual: {reserva.estado.value}"
        )

    # ── Paso 3: Cancelar la reserva ───────────────────────────
    reserva.estado = EstadoReservaEnum.canceled

    # ── Paso 4: Cancelar el pago asociado ────────────────────
    pago_result = await db.execute(
        select(Pago).where(Pago.reserva_id == reserva.id)
    )
    pago = pago_result.scalars().first()
    if pago:
        pago.estado = EstadoPagoEnum.rechazado

    # ── Paso 5: Commit cancelación (CRÍTICO — se guarda siempre) ──
    await db.commit()

    # ── Paso 6: Notificar al admin (no crítico) ────────────────
    try:
        cancha_result = await db.execute(select(Cancha).where(Cancha.id == reserva.cancha_id))
        cancha = cancha_result.scalar_one_or_none()

        cliente_result = await db.execute(
            select(User).where(User.id == uuid.UUID(current_user["id"]))
        )
        cliente = cliente_result.scalar_one_or_none()
        cliente_nombre = cliente.nombre if cliente else "Cliente"
        cancha_nombre = cancha.nombre if cancha else "Cancha"

        local_result2 = await db.execute(
            select(Local).where(Local.id == cancha.local_id)
        ) if cancha else None
        local2 = local_result2.scalar_one_or_none() if local_result2 else None

        admin = None
        if local2 and local2.admin_id:
            admin_result = await db.execute(
                select(User).where(User.id == local2.admin_id, User.activo == True)
            )
            admin = admin_result.scalar_one_or_none()

        if admin:
            await notif_reserva_cancelada_por_cliente(
                db=db,
                admin_id=admin.id,
                cliente_nombre=cliente_nombre,
                cancha_nombre=cancha_nombre,
                fecha=str(reserva.fecha),
                hora=str(reserva.hora_inicio)[:5],
                codigo=reserva.codigo
            )
            await db.commit()
    except Exception as e:
        logger.warning(f"Notificación de cancelación no enviada (reserva igual cancelada): {e}")

    return {
        "mensaje": f"Reserva {reserva.codigo} cancelada correctamente",
        "codigo": reserva.codigo,
        "estado": EstadoReservaEnum.canceled.value
    }