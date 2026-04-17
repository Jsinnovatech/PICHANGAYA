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
from app.models.cancha import Cancha
from app.models.local import Local
from app.models.plan_config import PlanConfig
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


class HistorialPagoResponse(BaseModel):
    id: uuid.UUID
    admin_nombre: str
    admin_celular: str
    plan: str
    monto: float
    metodo_pago: str
    estado: str
    voucher_url: Optional[str] = None
    fecha_pago: Optional[str] = None
    fecha_vencimiento: Optional[str] = None
    motivo_rechazo: Optional[str] = None
    created_at: Optional[str] = None

    class Config:
        from_attributes = True


# ══════════════════════════════════════════════
# DASHBOARD
# ══════════════════════════════════════════════

@router.get("/dashboard")
async def super_admin_dashboard(
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    ahora = datetime.now(timezone.utc)

    locales_result = await db.execute(
        select(func.count(Local.id)).where(Local.activo == True)
    )
    total_locales = locales_result.scalar() or 0

    clientes_result = await db.execute(
        select(func.count(User.id))
        .where(User.rol == RolEnum.cliente, User.activo == True)
    )
    total_clientes = clientes_result.scalar() or 0

    admins_result = await db.execute(
        select(func.count(User.id))
        .where(User.rol == RolEnum.admin, User.activo == True)
    )
    total_admins = admins_result.scalar() or 0

    # Admins distintos con suscripción activa
    admins_activos_result = await db.execute(
        select(func.count(func.distinct(Suscripcion.admin_id)))
        .where(
            Suscripcion.estado == EstadoSuscripcionEnum.activo,
            Suscripcion.fecha_vencimiento > ahora
        )
    )
    admins_con_suscripcion = admins_activos_result.scalar() or 0

    pendientes_result = await db.execute(
        select(func.count(Suscripcion.id))
        .where(Suscripcion.estado == EstadoSuscripcionEnum.pendiente)
    )
    suscripciones_pendientes = pendientes_result.scalar() or 0

    total_recaudado_result = await db.execute(
        select(func.sum(Suscripcion.monto))
        .where(Suscripcion.estado == EstadoSuscripcionEnum.activo)
    )
    total_recaudado = float(total_recaudado_result.scalar() or 0)

    inicio_mes = ahora.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    recaudado_mes_result = await db.execute(
        select(func.sum(Suscripcion.monto))
        .where(
            Suscripcion.estado == EstadoSuscripcionEnum.activo,
            Suscripcion.fecha_pago >= inicio_mes
        )
    )
    recaudado_mes = float(recaudado_mes_result.scalar() or 0)

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
            "admins_sin_suscripcion": max(0, total_admins - admins_con_suscripcion),
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
    ahora = datetime.now(timezone.utc)

    result = await db.execute(
        select(User)
        .where(User.rol == RolEnum.admin)
        .order_by(User.created_at.desc())
    )
    admins = result.scalars().all()

    respuesta = []
    for admin in admins:
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

        # Reservas en canchas de locales del admin
        reservas_result = await db.execute(
            select(func.count(Reserva.id))
            .join(Cancha, Cancha.id == Reserva.cancha_id)
            .join(Local, Local.id == Cancha.local_id)
            .where(Local.admin_id == admin.id)
        )
        total_reservas = reservas_result.scalar() or 0

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


@router.patch("/admins/{admin_id}/toggle-activo")
async def toggle_admin_activo(
    admin_id: uuid.UUID,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Suspende o reactiva un admin.
    activo=True → False (suspender) | activo=False → True (reactivar)
    """
    result = await db.execute(select(User).where(User.id == admin_id, User.rol == RolEnum.admin))
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(status_code=404, detail="Admin no encontrado")

    admin.activo = not admin.activo
    await db.commit()

    estado = "reactivado" if admin.activo else "suspendido"
    return {"mensaje": f"Admin {admin.nombre} {estado}", "activo": admin.activo}


# ══════════════════════════════════════════════
# ALERTAS DE VENCIMIENTO
# ══════════════════════════════════════════════

@router.get("/alertas-vencimiento")
async def alertas_vencimiento(
    dias: int = 15,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Admins cuya suscripción activa vence en los próximos `dias` días.
    dias: 7 | 15 | 30
    """
    ahora = datetime.now(timezone.utc)
    limite = ahora + timedelta(days=dias)

    result = await db.execute(
        select(Suscripcion)
        .where(
            Suscripcion.estado == EstadoSuscripcionEnum.activo,
            Suscripcion.fecha_vencimiento > ahora,
            Suscripcion.fecha_vencimiento <= limite,
        )
        .order_by(Suscripcion.fecha_vencimiento.asc())
    )
    suscripciones = result.scalars().all()

    respuesta = []
    for s in suscripciones:
        admin_r = await db.execute(select(User).where(User.id == s.admin_id))
        admin = admin_r.scalar_one_or_none()
        delta = s.fecha_vencimiento - ahora
        dias_restantes = max(0, delta.days)

        respuesta.append({
            "admin_id": str(s.admin_id),
            "admin_nombre": admin.nombre if admin else "—",
            "admin_celular": admin.celular if admin else "—",
            "plan": s.plan.value,
            "monto": float(s.monto),
            "fecha_vencimiento": str(s.fecha_vencimiento.date()),
            "dias_restantes": dias_restantes,
        })

    return respuesta


# ══════════════════════════════════════════════
# GESTIÓN DE SUSCRIPCIONES
# ══════════════════════════════════════════════

@router.get("/suscripciones-pendientes", response_model=List[SuscripcionPendienteResponse])
async def suscripciones_pendientes(
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Suscripcion)
        .where(Suscripcion.estado == EstadoSuscripcionEnum.pendiente)
        .order_by(Suscripcion.created_at.asc())
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
        suscripcion.verificado_por = uuid.UUID(current_user["id"])

        fecha_venc_str = suscripcion.fecha_vencimiento.strftime("%d/%m/%Y")

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


# ══════════════════════════════════════════════
# HISTORIAL COMPLETO DE PAGOS
# ══════════════════════════════════════════════

@router.get("/historial-pagos", response_model=List[HistorialPagoResponse])
async def historial_pagos(
    estado: Optional[str] = None,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Historial completo de suscripciones con filtro por estado.
    estado: 'activo' | 'rechazado' | 'vencido' | 'pendiente' | None (todos)
    """
    query = select(Suscripcion).order_by(Suscripcion.created_at.desc())

    if estado and estado in [e.value for e in EstadoSuscripcionEnum]:
        query = query.where(Suscripcion.estado == EstadoSuscripcionEnum(estado))

    result = await db.execute(query)
    suscripciones = result.scalars().all()

    respuesta = []
    for s in suscripciones:
        admin_r = await db.execute(select(User).where(User.id == s.admin_id))
        admin = admin_r.scalar_one_or_none()

        respuesta.append(HistorialPagoResponse(
            id=s.id,
            admin_nombre=admin.nombre if admin else "—",
            admin_celular=admin.celular if admin else "—",
            plan=s.plan.value,
            monto=float(s.monto),
            metodo_pago=s.metodo_pago,
            estado=s.estado.value,
            voucher_url=s.voucher_url,
            fecha_pago=str(s.fecha_pago.date()) if s.fecha_pago else None,
            fecha_vencimiento=str(s.fecha_vencimiento.date()) if s.fecha_vencimiento else None,
            motivo_rechazo=s.motivo_rechazo,
            created_at=str(s.created_at.date()) if s.created_at else None,
        ))

    return respuesta


# ══════════════════════════════════════════════
# GESTIÓN DE PLANES
# ══════════════════════════════════════════════

class ActualizarPlanRequest(BaseModel):
    nombre: Optional[str] = None
    precio: Optional[float] = None
    duracion_dias: Optional[int] = None
    descripcion: Optional[str] = None
    activo: Optional[bool] = None


@router.get("/planes")
async def listar_planes(
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(PlanConfig).order_by(PlanConfig.id))
    planes = result.scalars().all()
    return [
        {
            "id": p.id,
            "clave": p.clave,
            "nombre": p.nombre,
            "precio": float(p.precio),
            "duracion_dias": p.duracion_dias,
            "descripcion": p.descripcion,
            "activo": p.activo,
        }
        for p in planes
    ]


@router.put("/planes/{clave}")
async def actualizar_plan(
    clave: str,
    data: ActualizarPlanRequest,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(PlanConfig).where(PlanConfig.clave == clave))
    plan = result.scalar_one_or_none()

    if not plan:
        raise HTTPException(status_code=404, detail="Plan no encontrado")

    if data.nombre        is not None: plan.nombre        = data.nombre
    if data.precio        is not None: plan.precio        = data.precio
    if data.duracion_dias is not None: plan.duracion_dias = data.duracion_dias
    if data.descripcion   is not None: plan.descripcion   = data.descripcion
    if data.activo        is not None: plan.activo        = data.activo

    await db.commit()
    return {"mensaje": f"Plan '{clave}' actualizado", "clave": clave}


# ══════════════════════════════════════════════
# REPORTES DE INGRESOS
# ══════════════════════════════════════════════

@router.get("/reportes")
async def reportes(
    meses: int = 6,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    from sqlalchemy import extract

    ahora = datetime.now(timezone.utc)

    # ── Ingresos por mes ──────────────────────────────────
    ingresos_mes = []
    for i in range(meses - 1, -1, -1):
        if ahora.month - i > 0:
            anio = ahora.year
            mes  = ahora.month - i
        else:
            anio = ahora.year - 1
            mes  = ahora.month - i + 12

        res = await db.execute(
            select(func.sum(Suscripcion.monto), func.count(Suscripcion.id))
            .where(
                Suscripcion.estado == EstadoSuscripcionEnum.activo,
                extract('year',  Suscripcion.fecha_pago) == anio,
                extract('month', Suscripcion.fecha_pago) == mes,
            )
        )
        row = res.one()
        ingresos_mes.append({
            "mes": mes,
            "anio": anio,
            "total": float(row[0] or 0),
            "cantidad": int(row[1] or 0),
        })

    # ── Distribución por plan ─────────────────────────────
    planes_res = await db.execute(
        select(Suscripcion.plan, func.sum(Suscripcion.monto), func.count(Suscripcion.id))
        .where(Suscripcion.estado == EstadoSuscripcionEnum.activo)
        .group_by(Suscripcion.plan)
    )
    por_plan = [
        {"plan": row[0].value, "total": float(row[1] or 0), "cantidad": int(row[2] or 0)}
        for row in planes_res.all()
    ]

    # ── Top 5 admins ──────────────────────────────────────
    top_res = await db.execute(
        select(Suscripcion.admin_id, func.sum(Suscripcion.monto).label("total"))
        .where(Suscripcion.estado == EstadoSuscripcionEnum.activo)
        .group_by(Suscripcion.admin_id)
        .order_by(func.sum(Suscripcion.monto).desc())
        .limit(5)
    )
    top_admins = []
    for row in top_res.all():
        admin_r = await db.execute(select(User).where(User.id == row[0]))
        admin   = admin_r.scalar_one_or_none()
        top_admins.append({
            "nombre": admin.nombre if admin else "—",
            "total":  float(row[1] or 0),
        })

    return {
        "ingresos_por_mes": ingresos_mes,
        "por_plan": por_plan,
        "top_admins": top_admins,
    }
