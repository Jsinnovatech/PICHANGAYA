from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional
from datetime import datetime, timezone, timedelta
import uuid
import base64
import httpx

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.config import settings
from app.models.suscripcion import Suscripcion, PlanEnum, EstadoSuscripcionEnum
from app.models.user import User, RolEnum
from app.notificaciones import (
    notif_suscripcion_voucher_recibido,
    get_super_admin_id
)
from pydantic import BaseModel


router = APIRouter(prefix="/suscripcion", tags=["Suscripcion"])


# ══════════════════════════════════════════════
# SCHEMAS
# ══════════════════════════════════════════════

class IniciarPagoRequest(BaseModel):
    plan: str
    # 'basico' (S/.30) | 'premium' (S/.50)
    metodo_pago: str
    # 'yape' | 'plin' | 'transferencia'


class SuscripcionResponse(BaseModel):
    id: uuid.UUID
    plan: str
    monto: float
    metodo_pago: str
    estado: str
    voucher_url: Optional[str] = None
    fecha_pago: Optional[str] = None
    fecha_vencimiento: Optional[str] = None
    dias_restantes: Optional[int] = None
    # Cuántos días le quedan al admin antes que venza

    class Config:
        from_attributes = True


# ══════════════════════════════════════════════
# HELPER — verificar si admin tiene suscripción activa
# ══════════════════════════════════════════════

async def get_suscripcion_activa(
    admin_id: uuid.UUID,
    db: AsyncSession
) -> Suscripcion | None:
    """
    Devuelve la suscripción activa del admin si existe y no ha vencido.
    Si venció, actualiza el estado a 'vencido' automáticamente.
    """
    result = await db.execute(
        select(Suscripcion)
        .where(
            Suscripcion.admin_id == admin_id,
            Suscripcion.estado == EstadoSuscripcionEnum.activo
        )
        .order_by(Suscripcion.created_at.desc())
        .limit(1)
    )
    suscripcion = result.scalar_one_or_none()

    if not suscripcion:
        return None

    # Verificar si ya venció
    ahora = datetime.now(timezone.utc)
    if suscripcion.fecha_vencimiento and ahora > suscripcion.fecha_vencimiento:
        # Actualizar estado a vencido automáticamente
        suscripcion.estado = EstadoSuscripcionEnum.vencido
        await db.commit()
        return None

    return suscripcion


# ══════════════════════════════════════════════
# ENDPOINTS
# ══════════════════════════════════════════════

@router.get("/mi-suscripcion", response_model=SuscripcionResponse | None)
async def mi_suscripcion(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Devuelve el estado actual de la suscripción del admin.
    Flutter usa esto para mostrar el tab de suscripción con el estado correcto.
    Si no tiene suscripción activa → Flutter muestra pantalla de pago.
    """
    if current_user["rol"] not in ["admin", "super_admin"]:
        raise HTTPException(status_code=403, detail="Solo admins pueden ver suscripciones")

    admin_id = uuid.UUID(current_user["id"])

    # Buscar la última suscripción del admin (cualquier estado)
    result = await db.execute(
        select(Suscripcion)
        .where(Suscripcion.admin_id == admin_id)
        .order_by(Suscripcion.created_at.desc())
        .limit(1)
    )
    suscripcion = result.scalar_one_or_none()

    if not suscripcion:
        return None

    # Calcular días restantes si está activa
    dias_restantes = None
    if suscripcion.estado == EstadoSuscripcionEnum.activo and suscripcion.fecha_vencimiento:
        ahora = datetime.now(timezone.utc)
        delta = suscripcion.fecha_vencimiento - ahora
        dias_restantes = max(0, delta.days)

        # Si ya venció, actualizar estado
        if dias_restantes == 0:
            suscripcion.estado = EstadoSuscripcionEnum.vencido
            await db.commit()

    return SuscripcionResponse(
        id=suscripcion.id,
        plan=suscripcion.plan.value,
        monto=float(suscripcion.monto),
        metodo_pago=suscripcion.metodo_pago,
        estado=suscripcion.estado.value,
        voucher_url=suscripcion.voucher_url,
        fecha_pago=str(suscripcion.fecha_pago.date()) if suscripcion.fecha_pago else None,
        fecha_vencimiento=str(suscripcion.fecha_vencimiento.date()) if suscripcion.fecha_vencimiento else None,
        dias_restantes=dias_restantes
    )


@router.post("/pagar", response_model=SuscripcionResponse)
async def iniciar_pago_suscripcion(
    data: IniciarPagoRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    El admin inicia el proceso de pago de suscripción.
    Crea el registro en BD con estado pendiente.
    Luego el admin sube el voucher con /suscripcion/voucher.
    """
    if current_user["rol"] not in ["admin", "super_admin"]:
        raise HTTPException(status_code=403, detail="Solo admins pueden suscribirse")

    # Validar plan
    try:
        plan_enum = PlanEnum(data.plan)
    except ValueError:
        raise HTTPException(status_code=400, detail="Plan inválido. Use 'basico' o 'premium'")

    # Validar método de pago
    metodos_validos = ["yape", "plin", "transferencia"]
    if data.metodo_pago not in metodos_validos:
        raise HTTPException(
            status_code=400,
            detail=f"Método inválido. Use: {', '.join(metodos_validos)}"
        )

    # Determinar monto según plan
    monto = 30.00 if plan_enum == PlanEnum.basico else 50.00

    # Crear registro de suscripción pendiente
    nueva_suscripcion = Suscripcion(
        id=uuid.uuid4(),
        admin_id=uuid.UUID(current_user["id"]),
        plan=plan_enum,
        monto=monto,
        metodo_pago=data.metodo_pago,
        estado=EstadoSuscripcionEnum.pendiente
        # voucher_url = None hasta que suba la captura
        # fecha_pago = None hasta que super admin apruebe
        # fecha_vencimiento = None hasta que super admin apruebe
    )
    db.add(nueva_suscripcion)
    await db.commit()
    await db.refresh(nueva_suscripcion)

    return SuscripcionResponse(
        id=nueva_suscripcion.id,
        plan=nueva_suscripcion.plan.value,
        monto=float(nueva_suscripcion.monto),
        metodo_pago=nueva_suscripcion.metodo_pago,
        estado=nueva_suscripcion.estado.value,
        voucher_url=None,
        fecha_pago=None,
        fecha_vencimiento=None,
        dias_restantes=None
    )


@router.post("/{suscripcion_id}/voucher", response_model=SuscripcionResponse)
async def subir_voucher_suscripcion(
    suscripcion_id: uuid.UUID,
    imagen: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    El admin sube la captura de su pago de suscripción.
    Se sube a imgbb y se guarda la URL.
    Se notifica al super admin para que verifique.
    """

    # Verificar que la suscripción existe y es del admin
    result = await db.execute(
        select(Suscripcion).where(
            Suscripcion.id == suscripcion_id,
            Suscripcion.admin_id == uuid.UUID(current_user["id"])
        )
    )
    suscripcion = result.scalar_one_or_none()

    if not suscripcion:
        raise HTTPException(status_code=404, detail="Suscripción no encontrada")

    # Validar imagen
    tipos_permitidos = ["image/jpeg", "image/jpg", "image/png", "image/webp"]
    if imagen.content_type not in tipos_permitidos:
        raise HTTPException(status_code=400, detail="Solo JPG, PNG o WEBP")

    imagen_bytes = await imagen.read()
    if len(imagen_bytes) / (1024 * 1024) > 5:
        raise HTTPException(status_code=400, detail="Máximo 5MB")

    # Subir a imgbb
    imagen_base64 = base64.b64encode(imagen_bytes).decode("utf-8")
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.imgbb.com/1/upload",
            data={
                "key": settings.IMGBB_API_KEY,
                "name": f"suscripcion_{suscripcion_id}",
                "image": imagen_base64,
            },
            timeout=30.0
        )

    if response.status_code != 200:
        raise HTTPException(status_code=500, detail="Error al subir imagen")

    voucher_url = response.json()["data"]["url"]
    suscripcion.voucher_url = voucher_url

    # Obtener nombre del admin para la notificación
    admin_result = await db.execute(
        select(User).where(User.id == uuid.UUID(current_user["id"]))
    )
    admin = admin_result.scalar_one_or_none()
    admin_nombre = admin.nombre if admin else "Admin"

    # Notificar al super admin
    super_admin_id = await get_super_admin_id(db)
    if super_admin_id:
        await notif_suscripcion_voucher_recibido(
            db=db,
            admin_nombre=admin_nombre,
            plan=suscripcion.plan.value,
            super_admin_id=super_admin_id
        )

    await db.commit()
    await db.refresh(suscripcion)

    return SuscripcionResponse(
        id=suscripcion.id,
        plan=suscripcion.plan.value,
        monto=float(suscripcion.monto),
        metodo_pago=suscripcion.metodo_pago,
        estado=suscripcion.estado.value,
        voucher_url=suscripcion.voucher_url,
        fecha_pago=None,
        fecha_vencimiento=None,
        dias_restantes=None
    )