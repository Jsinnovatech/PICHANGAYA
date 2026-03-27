from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from datetime import date
import uuid

from app.core.database import get_db
from app.core.dependencies import require_admin
from app.models.reserva import Reserva, EstadoReservaEnum
from app.models.pago import Pago, EstadoPagoEnum
from app.models.user import User, RolEnum
from app.models.cancha import Cancha
from app.models.local import Local
from pydantic import BaseModel

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
    from datetime import datetime, timezone
    hoy = datetime.now(timezone.utc).date()

    reservas_hoy_result = await db.execute(
        select(func.count(Reserva.id)).where(Reserva.fecha == hoy)
    )
    reservas_hoy = reservas_hoy_result.scalar() or 0

    pendientes_result = await db.execute(
        select(func.count(Reserva.id)).where(Reserva.estado == EstadoReservaEnum.pending)
    )
    reservas_pendientes = pendientes_result.scalar() or 0

    ingresos_result = await db.execute(
        select(func.sum(Pago.monto)).where(
            Pago.estado == EstadoPagoEnum.verificado,
            func.date(Pago.created_at) == hoy
        )
    )
    ingresos_hoy = float(ingresos_result.scalar() or 0)

    clientes_result = await db.execute(
        select(func.count(User.id)).where(User.rol == RolEnum.cliente, User.activo == True)
    )
    total_clientes = clientes_result.scalar() or 0

    pagos_pendientes_result = await db.execute(
        select(func.count(Pago.id)).where(Pago.estado == EstadoPagoEnum.pendiente)
    )
    pagos_pendientes = pagos_pendientes_result.scalar() or 0

    ultimas_result = await db.execute(
        select(Reserva).order_by(Reserva.created_at.desc()).limit(5)
    )
    ultimas_reservas = ultimas_result.scalars().all()

    ultimas_lista = []
    for r in ultimas_reservas:
        cliente_r = await db.execute(select(User).where(User.id == r.cliente_id))
        cliente = cliente_r.scalar_one_or_none()
        cancha_r = await db.execute(select(Cancha).where(Cancha.id == r.cancha_id))
        cancha = cancha_r.scalar_one_or_none()
        ultimas_lista.append({
            "codigo": r.codigo,
            "cliente": cliente.nombre if cliente else "—",
            "cancha": cancha.nombre if cancha else "—",
            "fecha": str(r.fecha),
            "hora": str(r.hora_inicio)[:5],
            "estado": r.estado.value,
            "monto": float(r.precio_total)
        })

    return {
        "stats": {
            "reservas_hoy": reservas_hoy,
            "reservas_pendientes": reservas_pendientes,
            "ingresos_hoy": ingresos_hoy,
            "total_clientes": total_clientes,
            "pagos_pendientes": pagos_pendientes
        },
        "ultimas_reservas": ultimas_lista
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

    respuesta = []
    for reserva in reservas:
        cliente_result = await db.execute(select(User).where(User.id == reserva.cliente_id))
        cliente = cliente_result.scalar_one_or_none()

        cancha_result = await db.execute(select(Cancha).where(Cancha.id == reserva.cancha_id))
        cancha = cancha_result.scalar_one_or_none()

        local = None
        if cancha:
            local_result = await db.execute(select(Local).where(Local.id == cancha.local_id))
            local = local_result.scalar_one_or_none()

        pago_result = await db.execute(select(Pago).where(Pago.reserva_id == reserva.id))
        pago = pago_result.scalar_one_or_none()

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

    return respuesta


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

    await db.commit()

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