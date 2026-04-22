import logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from datetime import datetime, timezone, timedelta
import uuid

from app.core.database import get_db
from app.core.dependencies import get_current_user, require_super_admin
from app.core.security import hash_password
from app.models.suscripcion import Suscripcion, EstadoSuscripcionEnum
from app.models.user import User, RolEnum
from app.models.reserva import Reserva, EstadoReservaEnum
from app.models.pago import Pago, EstadoPagoEnum
from app.models.cancha import Cancha
from app.models.local import Local
from datetime import date
from app.models.plan_config import PlanConfig
from app.notificaciones import (
    notif_suscripcion_aprobada,
    notif_suscripcion_rechazada
)
from pydantic import BaseModel

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/super-admin", tags=["Super Admin"])


# require_super_admin viene de app.core.dependencies


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
    import asyncio
    ahora = datetime.now(timezone.utc)

    try:
        result = await db.execute(
            select(User)
            .where(User.rol == RolEnum.admin)
            .order_by(User.created_at.desc())
        )
        admins = result.scalars().all()
    except Exception as e:
        logger.error(f"Error al consultar admins: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error al consultar admins: {str(e)}")

    if not admins:
        return []

    admin_ids = [a.id for a in admins]

    # ── Batch: suscripciones activas de todos los admins en 1 query ──
    try:
        sus_rows = (await db.execute(
            select(Suscripcion)
            .where(
                Suscripcion.admin_id.in_(admin_ids),
                Suscripcion.estado == EstadoSuscripcionEnum.activo,
            )
            .order_by(Suscripcion.created_at.desc())
        )).scalars().all()
    except Exception as e:
        logger.error(f"Error al consultar suscripciones: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error al consultar suscripciones: {str(e)}")

    # Mapa admin_id → suscripción más reciente activa
    sus_map: dict[uuid.UUID, Suscripcion] = {}
    for s in sus_rows:
        if s.admin_id not in sus_map:
            sus_map[s.admin_id] = s

    # ── Batch: count de reservas por admin en 1 query ──────────────
    try:
        reservas_rows = (await db.execute(
            select(Local.admin_id, func.count(Reserva.id).label("total"))
            .join(Cancha, Cancha.local_id == Local.id)
            .join(Reserva, Reserva.cancha_id == Cancha.id)
            .where(Local.admin_id.in_(admin_ids))
            .group_by(Local.admin_id)
        )).all()
        reservas_map: dict[uuid.UUID, int] = {row[0]: int(row[1]) for row in reservas_rows}
    except Exception as e:
        logger.warning(f"Error al consultar reservas por admin (se usará 0): {e}")
        reservas_map = {}

    # ── Construir respuesta ────────────────────────────────────────
    respuesta = []
    for admin in admins:
        suscripcion = sus_map.get(admin.id)

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

        respuesta.append(AdminConSuscripcionResponse(
            id=admin.id,
            nombre=admin.nombre,
            celular=admin.celular,
            activo=admin.activo,
            tiene_suscripcion_activa=tiene_activa,
            plan_actual=plan_actual,
            fecha_vencimiento=fecha_vencimiento,
            dias_restantes=dias_restantes,
            total_reservas_gestionadas=reservas_map.get(admin.id, 0),
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

    try:
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
    except Exception as e:
        logger.error(f"Error alertas-vencimiento: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

    if not suscripciones:
        return []

    # Batch: traer admins en 1 query
    admin_ids = list({s.admin_id for s in suscripciones})
    admins_map = {
        u.id: u for u in (await db.execute(
            select(User).where(User.id.in_(admin_ids))
        )).scalars().all()
    }

    respuesta = []
    for s in suscripciones:
        admin = admins_map.get(s.admin_id)
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
    try:
        result = await db.execute(
            select(Suscripcion)
            .where(Suscripcion.estado == EstadoSuscripcionEnum.pendiente)
            .order_by(Suscripcion.created_at.asc())
        )
        suscripciones = result.scalars().all()
    except Exception as e:
        logger.error(f"Error suscripciones-pendientes: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

    if not suscripciones:
        return []

    # Batch: traer admins en 1 query
    admin_ids = list({s.admin_id for s in suscripciones})
    admins_map = {
        u.id: u for u in (await db.execute(
            select(User).where(User.id.in_(admin_ids))
        )).scalars().all()
    }

    respuesta = []
    for s in suscripciones:
        admin = admins_map.get(s.admin_id)

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

    try:
        result = await db.execute(query)
        suscripciones = result.scalars().all()
    except Exception as e:
        logger.error(f"Error historial-pagos: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

    if not suscripciones:
        return []

    # Batch: traer admins en 1 query
    admin_ids = list({s.admin_id for s in suscripciones})
    admins_map = {
        u.id: u for u in (await db.execute(
            select(User).where(User.id.in_(admin_ids))
        )).scalars().all()
    }

    respuesta = []
    for s in suscripciones:
        admin = admins_map.get(s.admin_id)

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


# ══════════════════════════════════════════════
# RESERVAS GLOBALES (todas las canchas)
# ══════════════════════════════════════════════

class ReservaSuperAdminResponse(BaseModel):
    id: uuid.UUID
    codigo: str
    cliente_nombre: str
    cliente_celular: str
    cancha_nombre: Optional[str] = None
    local_nombre: Optional[str] = None
    admin_nombre: Optional[str] = None
    fecha: date
    hora_inicio: str
    hora_fin: str
    precio_total: float
    estado: str
    tipo_doc: Optional[str] = None
    metodo_pago: Optional[str] = None
    pago_estado: Optional[str] = None

    class Config:
        from_attributes = True


@router.get("/reservas", response_model=List[ReservaSuperAdminResponse])
async def super_admin_get_reservas(
    estado: Optional[str] = None,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    import asyncio

    try:
        query = (
            select(Reserva)
            .join(Cancha, Cancha.id == Reserva.cancha_id)
            .join(Local, Local.id == Cancha.local_id)
            .order_by(Reserva.created_at.desc())
        )
        if estado:
            try:
                estado_enum = EstadoReservaEnum(estado)
                query = query.where(Reserva.estado == estado_enum)
            except ValueError:
                raise HTTPException(status_code=400, detail=f"Estado inválido: {estado}")

        result = await db.execute(query)
        reservas = result.scalars().all()
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[super_admin] Error al consultar reservas: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

    if not reservas:
        return []

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

    admin_ids = list({l.admin_id for l in locales_map.values() if l.admin_id})
    admins_map = {
        u.id: u for u in (await db.execute(
            select(User).where(User.id.in_(admin_ids))
        )).scalars().all()
    } if admin_ids else {}

    respuesta = []
    for reserva in reservas:
        try:
            cliente = clientes_map.get(reserva.cliente_id)
            cancha  = canchas_map.get(reserva.cancha_id)
            local   = locales_map.get(cancha.local_id) if cancha else None
            admin   = admins_map.get(local.admin_id) if local and local.admin_id else None
            pago    = pagos_map.get(reserva.id)

            respuesta.append(ReservaSuperAdminResponse(
                id=reserva.id,
                codigo=reserva.codigo,
                cliente_nombre=cliente.nombre if cliente else "Desconocido",
                cliente_celular=cliente.celular if cliente else "",
                cancha_nombre=cancha.nombre if cancha else None,
                local_nombre=local.nombre if local else None,
                admin_nombre=admin.nombre if admin else None,
                fecha=reserva.fecha,
                hora_inicio=str(reserva.hora_inicio)[:5],
                hora_fin=str(reserva.hora_fin)[:5],
                precio_total=float(reserva.precio_total),
                estado=reserva.estado.value,
                tipo_doc=reserva.tipo_doc.value if reserva.tipo_doc else None,
                metodo_pago=pago.metodo.value if pago else None,
                pago_estado=pago.estado.value if pago else None,
            ))
        except Exception as e:
            logger.error(f"[super_admin] Error procesando reserva {reserva.id}: {e}", exc_info=True)
            continue

    return respuesta


# ══════════════════════════════════════════════
# CREAR / EDITAR ADMINS
# ══════════════════════════════════════════════

class AdminCreateRequest(BaseModel):
    celular: str
    nombre: str
    password: str
    dni: Optional[str] = None


class AdminEditRequest(BaseModel):
    nombre: Optional[str] = None
    celular: Optional[str] = None
    dni: Optional[str] = None
    password: Optional[str] = None


@router.post("/admins", status_code=201)
async def crear_admin(
    data: AdminCreateRequest,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    import re
    celular = data.celular.replace(" ", "").replace("-", "").replace("+51", "")
    if not re.match(r"^\d{9}$", celular):
        raise HTTPException(status_code=400, detail="El celular debe tener 9 dígitos")
    if len(data.password) < 8 or not any(c.isdigit() for c in data.password):
        raise HTTPException(status_code=400, detail="La contraseña debe tener al menos 8 caracteres y un número")
    dni = None
    if data.dni:
        dni = data.dni.strip()
        if not re.match(r"^\d{8}$", dni):
            raise HTTPException(status_code=400, detail="El DNI debe tener exactamente 8 dígitos")

    existing = await db.execute(select(User).where(User.celular == celular))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="El celular ya está registrado")

    new_admin = User(
        celular=celular,
        nombre=data.nombre.strip(),
        dni=dni,
        password_hash=hash_password(data.password),
        rol=RolEnum.admin,
        activo=True,
    )
    db.add(new_admin)
    await db.commit()
    await db.refresh(new_admin)

    return {
        "id": str(new_admin.id),
        "celular": new_admin.celular,
        "nombre": new_admin.nombre,
        "dni": new_admin.dni,
        "activo": new_admin.activo,
        "rol": new_admin.rol.value,
        "mensaje": f"Admin {new_admin.nombre} creado exitosamente"
    }


@router.get("/admins/{admin_id}")
async def detalle_admin(
    admin_id: uuid.UUID,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(User).where(User.id == admin_id, User.rol == RolEnum.admin))
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=404, detail="Admin no encontrado")

    return {
        "id": str(admin.id),
        "celular": admin.celular,
        "nombre": admin.nombre,
        "dni": admin.dni,
        "activo": admin.activo,
        "rol": admin.rol.value,
    }


@router.patch("/admins/{admin_id}")
async def editar_admin(
    admin_id: uuid.UUID,
    data: AdminEditRequest,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    import re
    result = await db.execute(select(User).where(User.id == admin_id, User.rol == RolEnum.admin))
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=404, detail="Admin no encontrado")

    if data.nombre is not None:
        admin.nombre = data.nombre.strip()
    if data.celular is not None:
        celular = data.celular.replace(" ", "").replace("-", "").replace("+51", "")
        if not re.match(r"^\d{9}$", celular):
            raise HTTPException(status_code=400, detail="El celular debe tener 9 dígitos")
        dup = await db.execute(select(User).where(User.celular == celular, User.id != admin_id))
        if dup.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="El celular ya está en uso")
        admin.celular = celular
    if data.dni is not None:
        dni = data.dni.strip()
        if dni and not re.match(r"^\d{8}$", dni):
            raise HTTPException(status_code=400, detail="El DNI debe tener exactamente 8 dígitos")
        admin.dni = dni or None
    if data.password is not None and data.password.strip():
        if len(data.password) < 8 or not any(c.isdigit() for c in data.password):
            raise HTTPException(status_code=400, detail="La contraseña debe tener al menos 8 caracteres y un número")
        admin.password_hash = hash_password(data.password)

    await db.commit()
    return {"mensaje": f"Admin {admin.nombre} actualizado", "id": str(admin_id)}


# ══════════════════════════════════════════════
# GESTIÓN DE LOCALES
# ══════════════════════════════════════════════

class LocalCreateRequest(BaseModel):
    admin_id: uuid.UUID
    nombre: str
    direccion: str
    lat: float
    lng: float
    telefono: Optional[str] = None
    descripcion: Optional[str] = None
    precio_desde: float = 0.0
    activo: bool = True


class LocalEditRequest(BaseModel):
    nombre: Optional[str] = None
    direccion: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    telefono: Optional[str] = None
    descripcion: Optional[str] = None
    activo: Optional[bool] = None


@router.post("/locales", status_code=201)
async def crear_local(
    data: LocalCreateRequest,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    admin_r = await db.execute(
        select(User).where(User.id == data.admin_id, User.rol == RolEnum.admin)
    )
    admin = admin_r.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=400, detail="Admin no encontrado o el usuario no tiene rol de admin")

    new_local = Local(
        admin_id=data.admin_id,
        nombre=data.nombre.strip(),
        direccion=data.direccion.strip(),
        lat=data.lat,
        lng=data.lng,
        telefono=data.telefono,
        descripcion=data.descripcion,
        activo=data.activo,
    )
    db.add(new_local)
    await db.commit()
    await db.refresh(new_local)

    return {
        "id": str(new_local.id),
        "nombre": new_local.nombre,
        "direccion": new_local.direccion,
        "lat": float(new_local.lat),
        "lng": float(new_local.lng),
        "activo": new_local.activo,
        "admin_nombre": admin.nombre,
        "admin_celular": admin.celular,
        "num_canchas": 0,
        "mensaje": f"Local '{new_local.nombre}' creado exitosamente"
    }


@router.get("/locales")
async def listar_locales(
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    try:
        locales_result = await db.execute(select(Local).order_by(Local.created_at.desc()))
        locales = locales_result.scalars().all()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    if not locales:
        return []

    admin_ids = list({l.admin_id for l in locales if l.admin_id})
    admins_map = {}
    if admin_ids:
        admins_rows = await db.execute(select(User).where(User.id.in_(admin_ids)))
        admins_map = {u.id: u for u in admins_rows.scalars().all()}

    local_ids = [l.id for l in locales]
    canchas_rows = await db.execute(
        select(Cancha.local_id, func.count(Cancha.id).label("total"))
        .where(Cancha.local_id.in_(local_ids))
        .group_by(Cancha.local_id)
    )
    canchas_count_map = {row[0]: int(row[1]) for row in canchas_rows.all()}

    return [
        {
            "id": str(l.id),
            "nombre": l.nombre,
            "direccion": l.direccion,
            "lat": float(l.lat),
            "lng": float(l.lng),
            "telefono": l.telefono,
            "descripcion": l.descripcion,
            "activo": l.activo,
            "admin_id": str(l.admin_id) if l.admin_id else None,
            "admin_nombre": admins_map[l.admin_id].nombre if l.admin_id and l.admin_id in admins_map else "Sin asignar",
            "admin_celular": admins_map[l.admin_id].celular if l.admin_id and l.admin_id in admins_map else "",
            "num_canchas": canchas_count_map.get(l.id, 0),
        }
        for l in locales
    ]


@router.get("/locales/{local_id}")
async def detalle_local(
    local_id: uuid.UUID,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Local).where(Local.id == local_id))
    local = result.scalar_one_or_none()
    if not local:
        raise HTTPException(status_code=404, detail="Local no encontrado")

    admin = None
    if local.admin_id:
        admin_r = await db.execute(select(User).where(User.id == local.admin_id))
        admin = admin_r.scalar_one_or_none()

    num_canchas = (await db.execute(
        select(func.count(Cancha.id)).where(Cancha.local_id == local_id)
    )).scalar() or 0

    return {
        "id": str(local.id),
        "nombre": local.nombre,
        "direccion": local.direccion,
        "lat": float(local.lat),
        "lng": float(local.lng),
        "telefono": local.telefono,
        "descripcion": local.descripcion,
        "activo": local.activo,
        "admin_id": str(local.admin_id) if local.admin_id else None,
        "admin_nombre": admin.nombre if admin else "Sin asignar",
        "admin_celular": admin.celular if admin else "",
        "num_canchas": num_canchas,
    }


@router.patch("/locales/{local_id}")
async def editar_local(
    local_id: uuid.UUID,
    data: LocalEditRequest,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Local).where(Local.id == local_id))
    local = result.scalar_one_or_none()
    if not local:
        raise HTTPException(status_code=404, detail="Local no encontrado")

    if data.nombre      is not None: local.nombre      = data.nombre.strip()
    if data.direccion   is not None: local.direccion   = data.direccion.strip()
    if data.lat         is not None: local.lat         = data.lat
    if data.lng         is not None: local.lng         = data.lng
    if data.telefono    is not None: local.telefono    = data.telefono
    if data.descripcion is not None: local.descripcion = data.descripcion
    if data.activo      is not None: local.activo      = data.activo

    await db.commit()
    return {"mensaje": f"Local '{local.nombre}' actualizado", "id": str(local_id)}


@router.patch("/locales/{local_id}/toggle")
async def toggle_local(
    local_id: uuid.UUID,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Local).where(Local.id == local_id))
    local = result.scalar_one_or_none()
    if not local:
        raise HTTPException(status_code=404, detail="Local no encontrado")

    local.activo = not local.activo
    await db.commit()
    estado = "activado" if local.activo else "desactivado"
    return {"mensaje": f"Local '{local.nombre}' {estado}", "activo": local.activo}


# ══════════════════════════════════════════════
# GESTIÓN DE CANCHAS (desde Super Admin)
# ══════════════════════════════════════════════

class CanchaCreateRequest(BaseModel):
    nombre: str
    descripcion: Optional[str] = None
    precio_hora: float
    capacidad: int = 10
    activo: bool = True


class CanchaEditRequest(BaseModel):
    nombre: Optional[str] = None
    descripcion: Optional[str] = None
    precio_hora: Optional[float] = None
    capacidad: Optional[int] = None
    activa: Optional[bool] = None


@router.post("/locales/{local_id}/canchas", status_code=201)
async def crear_cancha(
    local_id: uuid.UUID,
    data: CanchaCreateRequest,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    local_r = await db.execute(select(Local).where(Local.id == local_id))
    if not local_r.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Local no encontrado")

    new_cancha = Cancha(
        local_id=local_id,
        nombre=data.nombre.strip(),
        descripcion=data.descripcion,
        precio_hora=data.precio_hora,
        capacidad=data.capacidad,
        activa=data.activo,
    )
    db.add(new_cancha)
    await db.commit()
    await db.refresh(new_cancha)

    return {
        "id": str(new_cancha.id),
        "nombre": new_cancha.nombre,
        "descripcion": new_cancha.descripcion,
        "precio_hora": float(new_cancha.precio_hora),
        "capacidad": new_cancha.capacidad,
        "activa": new_cancha.activa,
        "local_id": str(local_id),
        "mensaje": f"Cancha '{new_cancha.nombre}' creada exitosamente"
    }


@router.get("/locales/{local_id}/canchas")
async def listar_canchas_local(
    local_id: uuid.UUID,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    local_r = await db.execute(select(Local).where(Local.id == local_id))
    if not local_r.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Local no encontrado")

    canchas = (await db.execute(
        select(Cancha).where(Cancha.local_id == local_id).order_by(Cancha.created_at)
    )).scalars().all()

    return [
        {
            "id": str(c.id),
            "nombre": c.nombre,
            "descripcion": c.descripcion,
            "precio_hora": float(c.precio_hora),
            "capacidad": c.capacidad,
            "activa": c.activa,
            "local_id": str(c.local_id),
        }
        for c in canchas
    ]


@router.patch("/canchas/{cancha_id}")
async def editar_cancha(
    cancha_id: uuid.UUID,
    data: CanchaEditRequest,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Cancha).where(Cancha.id == cancha_id))
    cancha = result.scalar_one_or_none()
    if not cancha:
        raise HTTPException(status_code=404, detail="Cancha no encontrada")

    if data.nombre      is not None: cancha.nombre      = data.nombre.strip()
    if data.descripcion is not None: cancha.descripcion = data.descripcion
    if data.precio_hora is not None: cancha.precio_hora = data.precio_hora
    if data.capacidad   is not None: cancha.capacidad   = data.capacidad
    if data.activa      is not None: cancha.activa      = data.activa

    await db.commit()
    return {"mensaje": f"Cancha '{cancha.nombre}' actualizada", "id": str(cancha_id)}


@router.patch("/canchas/{cancha_id}/toggle")
async def toggle_cancha(
    cancha_id: uuid.UUID,
    current_user: dict = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Cancha).where(Cancha.id == cancha_id))
    cancha = result.scalar_one_or_none()
    if not cancha:
        raise HTTPException(status_code=404, detail="Cancha no encontrada")

    cancha.activa = not cancha.activa
    await db.commit()
    estado = "activada" if cancha.activa else "desactivada"
    return {"mensaje": f"Cancha '{cancha.nombre}' {estado}", "activa": cancha.activa}
