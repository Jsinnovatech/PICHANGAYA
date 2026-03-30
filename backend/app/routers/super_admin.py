from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from datetime import datetime, timezone, timedelta
import uuid

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.suscripcion import Suscripcion, EstadoSuscripcionEnum
from app.models.user import User, RolEnum
from app.models.reserva import Reserva
from app.models.pago import Pago, EstadoPagoEnum
from app.models.local import Local
from app.notificaciones import (
    notif_suscripcion_aprobada,
    notif_suscripcion_rechazada
)
from pydantic import BaseModel


router = APIRouter(prefix="/super-admin", tags=["Super Admin"])


# ══════════════════════════════════════════════
# DEPENDENCY — solo super_admin puede acceder
# ══════════════════════════════════════════════

async def require_super_admin(current_user: dict = Depends(get_current_user)):
    if current_user["rol"] != "super_admin":
        raise HTTPException(
            status_code=403,
            detail="Solo el super admin puede acceder a este recurso"
        )
    return current_user


# ══════════════════════════════════════════════
# SCHEMAS
# ══════════════════════════════════════════════

class AdminConSuscripcionResponse(BaseModel):
    id: uuid.UUID
    nombre: str
    celular: str
    activo: bool
    tiene_suscripcion_activa: bool
    plan_actual: Optional[str] = None
    fecha_vencimiento: Optional[str] = None
    dias_restantes: Optional[int] = None
    total_reservas_gestionadas: int = 0

    class Config:
        from_attributes = True


class SuscripcionPendienteResponse(BaseModel):
    id: uuid.UUID
    admin_id: uuid.UUID
    admin_nombre: str
    admin_celular: str
    plan: str
    monto: float
    metodo_pago: str
    voucher_url: Optional[str] = None
    created_at: Optional[str] = None

    class Config:
        from_attributes = True


class VerificarSuscripcionRequest(BaseModel):
    accion: str
    # 'aprobar' | 'rechazar'
    motivo: Optional[str] = None
    # Motivo del rechazo — se envía al admin como notificación


# ══════════════════════════════════════════════
# DASHBOARD
# ══════════════════════════════════════════════

@router.get("/dashboard")
async def super_admin_dashboard(
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Dashboard completo del super admin con todas las estadísticas del sistema.
    """
    ahora = datetime.now(timezone.utc)

    # Total complejos deportivos registrados
    locales_result = await db.execute(
        select(func.count(Local.id)).where(Local.activo == True)
    )
    total_locales = locales_result.scalar() or 0

    # Total clientes registrados y activos
    clientes_result = await db.execute(
        select(func.count(User.id))
        .where(User.rol == RolEnum.cliente, User.activo == True)
    )
    total_clientes = clientes_result.scalar() or 0

    # Total admins registrados
    admins_result = await db.execute(
        select(func.count(User.id))
        .where(User.rol == RolEnum.admin, User.activo == True)
    )
    total_admins = admins_result.scalar() or 0

    # Admins con suscripción activa
    admins_activos_result = await db.execute(
        select(func.count(Suscripcion.id))
        .where(
            Suscripcion.estado == EstadoSuscripcionEnum.activo,
            Suscripcion.fecha_vencimiento > ahora
        )
    )
    admins_con_suscripcion = admins_activos_result.scalar() or 0

    # Suscripciones pendientes de verificar
    pendientes_result = await db.execute(
        select(func.count(Suscripcion.id))
        .where(Suscripcion.estado == EstadoSuscripcionEnum.pendiente)
    )
    suscripciones_pendientes = pendientes_result.scalar() or 0

    # Total recaudado histórico
    total_recaudado_result = await db.execute(
        select(func.sum(Suscripcion.monto))
        .where(Suscripcion.estado == EstadoSuscripcionEnum.activo)
    )
    total_recaudado = float(total_recaudado_result.scalar() or 0)

    # Recaudado este mes
    inicio_mes = ahora.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    recaudado_mes_result = await db.execute(
        select(func.sum(Suscripcion.monto))
        .where(
            Suscripcion.estado == EstadoSuscripcionEnum.activo,
            Suscripcion.fecha_pago >= inicio_mes
        )
    )
    recaudado_mes = float(recaudado_mes_result.scalar() or 0)

    # Recaudado mes anterior
    inicio_mes_anterior = (inicio_mes - timedelta(days=1)).replace(day=1)
    recaudado_mes_anterior_result = await db.execute(
        select(func.sum(Suscripcion.monto))
        .where(
            Suscripcion.estado == EstadoSuscripcionEnum.activo,
            Suscripcion.fecha_pago >= inicio_mes_anterior,
            Suscripcion.fecha_pago < inicio_mes
        )
    )
    recaudado_mes_anterior = float(recaudado_mes_anterior_result.scalar() or 0)

    # Últimas 5 suscripciones aprobadas
    ultimas_suscripciones_result = await db.execute(
        select(Suscripcion)
        .where(Suscripcion.estado == EstadoSuscripcionEnum.activo)
        .order_by(Suscripcion.fecha_pago.desc())
        .limit(5)
    )
    ultimas_suscripciones = ultimas_suscripciones_result.scalars().all()

    ultimas_lista = []
    for s in ultimas_suscripciones:
        admin_r = await db.execute(select(User).where(User.id == s.admin_id))
        admin = admin_r.scalar_one_or_none()
        ultimas_lista.append({
            "admin": admin.nombre if admin else "—",
            "plan": s.plan.value,
            "monto": float(s.monto),
            "fecha_pago": str(s.fecha_pago.date()) if s.fecha_pago else "—",
            "vence": str(s.fecha_vencimiento.date()) if s.fecha_vencimiento else "—"
        })

    return {
        "stats": {
            "total_locales": total_locales,
            "total_clientes": total_clientes,
            "total_admins": total_admins,
            "admins_con_suscripcion_activa": admins_con_suscripcion,
            "admins_sin_suscripcion": total_admins - admins_con_suscripcion,
            "suscripciones_pendientes": suscripciones_pendientes,
            "total_recaudado": total_recaudado,
            "recaudado_este_mes": recaudado_mes,
            "recaudado_mes_anterior": recaudado_mes_anterior,
        },
        "ultimas_suscripciones": ultimas_lista
    }


# ══════════════════════════════════════════════
# GESTIÓN DE ADMINS
# ══════════════════════════════════════════════

@router.get("/admins", response_model=List[AdminConSuscripcionResponse])
async def listar_admins(
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Lista todos los admins con su estado de suscripción.
    """
    ahora = datetime.now(timezone.utc)

    result = await db.execute(
        select(User)
        .where(User.rol == RolEnum.admin)
        .order_by(User.created_at.desc())
    )
    admins = result.scalars().all()

    respuesta = []
    for admin in admins:
        # Buscar suscripción activa
        sus_result = await db.execute(
            select(Suscripcion)
            .where(
                Suscripcion.admin_id == admin.id,
                Suscripcion.estado == EstadoSuscripcionEnum.activo
            )
            .order_by(Suscripcion.created_at.desc())
            .limit(1)
        )
        suscripcion = sus_result.scalar_one_or_none()

        tiene_activa = False
        plan_actual = None
        fecha_vencimiento = None
        dias_restantes = None

        if suscripcion and suscripcion.fecha_vencimiento:
            if ahora < suscripcion.fecha_vencimiento:
                tiene_activa = True
                plan_actual = suscripcion.plan.value
                fecha_vencimiento = str(suscripcion.fecha_vencimiento.date())
                delta = suscripcion.fecha_vencimiento - ahora
                dias_restantes = max(0, delta.days)

        # Contar reservas gestionadas por este admin
        # (reservas de canchas de sus locales)
        reservas_result = await db.execute(
            select(func.count(Reserva.id))
            .join(Local, Local.id == Reserva.cancha_id)
            # Aproximación — en producción filtrar por local del admin
        )
        total_reservas = 0

        respuesta.append(AdminConSuscripcionResponse(
            id=admin.id,
            nombre=admin.nombre,
            celular=admin.celular,
            activo=admin.activo,
            tiene_suscripcion_activa=tiene_activa,
            plan_actual=plan_actual,
            fecha_vencimiento=fecha_vencimiento,
            dias_restantes=dias_restantes,
            total_reservas_gestionadas=total_reservas
        ))

    return respuesta


# ══════════════════════════════════════════════
# GESTIÓN DE SUSCRIPCIONES
# ══════════════════════════════════════════════

@router.get("/suscripciones-pendientes", response_model=List[SuscripcionPendienteResponse])
async def suscripciones_pendientes(
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Lista todas las suscripciones pendientes de verificar.
    El super admin las revisa y aprueba/rechaza.
    """
    result = await db.execute(
        select(Suscripcion)
        .where(Suscripcion.estado == EstadoSuscripcionEnum.pendiente)
        .order_by(Suscripcion.created_at.asc())
        # Las más antiguas primero — FIFO
    )
    suscripciones = result.scalars().all()

    respuesta = []
    for s in suscripciones:
        admin_r = await db.execute(select(User).where(User.id == s.admin_id))
        admin = admin_r.scalar_one_or_none()

        respuesta.append(SuscripcionPendienteResponse(
            id=s.id,
            admin_id=s.admin_id,
            admin_nombre=admin.nombre if admin else "—",
            admin_celular=admin.celular if admin else "—",
            plan=s.plan.value,
            monto=float(s.monto),
            metodo_pago=s.metodo_pago,
            voucher_url=s.voucher_url,
            created_at=str(s.created_at.date()) if s.created_at else None
        ))

    return respuesta


@router.patch("/suscripciones/{suscripcion_id}/verificar")
async def verificar_suscripcion(
    suscripcion_id: uuid.UUID,
    data: VerificarSuscripcionRequest,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Super admin aprueba o rechaza una suscripción.
    Si aprueba → activa al admin por 30 días + notificación.
    Si rechaza → notifica al admin con el motivo.
    """
    result = await db.execute(
        select(Suscripcion).where(Suscripcion.id == suscripcion_id)
    )
    suscripcion = result.scalar_one_or_none()

    if not suscripcion:
        raise HTTPException(status_code=404, detail="Suscripción no encontrada")

    if data.accion == "aprobar":
        ahora = datetime.now(timezone.utc)
        suscripcion.estado = EstadoSuscripcionEnum.activo
        suscripcion.fecha_pago = ahora
        suscripcion.fecha_vencimiento = ahora + timedelta(days=30)
        # 30 días desde ahora
        suscripcion.verificado_por = uuid.UUID(current_user["id"])

        fecha_venc_str = suscripcion.fecha_vencimiento.strftime("%d/%m/%Y")

        # Notificar al admin
        await notif_suscripcion_aprobada(
            db=db,
            admin_id=suscripcion.admin_id,
            plan=suscripcion.plan.value,
            fecha_vencimiento=fecha_venc_str
        )
        mensaje = f"Suscripción aprobada — Admin activo hasta {fecha_venc_str}"

    elif data.accion == "rechazar":
        suscripcion.estado = EstadoSuscripcionEnum.rechazado
        suscripcion.verificado_por = uuid.UUID(current_user["id"])
        motivo = data.motivo or "No especificado"
        suscripcion.motivo_rechazo = motivo

        # Notificar al admin
        await notif_suscripcion_rechazada(
            db=db,
            admin_id=suscripcion.admin_id,
            motivo=motivo
        )
        mensaje = f"Suscripción rechazada — Motivo: {motivo}"

    else:
        raise HTTPException(
            status_code=400,
            detail="Acción inválida. Use 'aprobar' o 'rechazar'"
        )

    await db.commit()

    return {
        "mensaje": mensaje,
        "suscripcion_id": str(suscripcion_id),
        "accion": data.accion
    }