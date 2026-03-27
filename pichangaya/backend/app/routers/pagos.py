from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
import uuid
import httpx
import base64

from app.core.database import get_db
from app.core.config import settings
from app.core.dependencies import get_current_user
from app.models.pago import Pago, EstadoPagoEnum
from app.models.reserva import Reserva
from app.models.cancha import Cancha
from app.models.local import Local
from app.models.user import User
from app.schemas.pagos import VoucherUploadResponse, PagoClienteResponse
from app.notificaciones import notif_reserva_voucher_recibido

router = APIRouter(prefix="/pagos", tags=["Pagos"])


async def subir_imagen_imgbb(imagen_bytes: bytes, nombre: str) -> str:
    imagen_base64 = base64.b64encode(imagen_bytes).decode("utf-8")
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.imgbb.com/1/upload",
            data={
                "key": settings.IMGBB_API_KEY,
                "name": nombre,
                "image": imagen_base64,
            },
            timeout=30.0
        )
    if response.status_code != 200:
        raise HTTPException(status_code=500, detail="Error al subir imagen a imgbb")
    return response.json()["data"]["url"]


@router.get("/mis-pagos", response_model=List[PagoClienteResponse])
async def mis_pagos(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Pago)
        .where(Pago.cliente_id == uuid.UUID(current_user["id"]))
        .order_by(Pago.created_at.desc())
    )
    pagos = result.scalars().all()

    respuesta = []
    for pago in pagos:
        reserva_result = await db.execute(
            select(Reserva).where(Reserva.id == pago.reserva_id)
        )
        reserva = reserva_result.scalar_one_or_none()

        respuesta.append(PagoClienteResponse(
            id=pago.id,
            reserva_id=pago.reserva_id,
            reserva_codigo=reserva.codigo if reserva else None,
            monto=float(pago.monto),
            metodo=pago.metodo.value,
            estado=pago.estado.value,
            voucher_url=pago.voucher_url,
            fecha=str(pago.created_at.date()) if pago.created_at else None
        ))

    return respuesta


@router.post("/{pago_id}/voucher", response_model=VoucherUploadResponse)
async def subir_voucher(
    pago_id: uuid.UUID,
    imagen: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # ── Verificar pago ────────────────────────────────────────
    result = await db.execute(
        select(Pago).where(
            Pago.id == pago_id,
            Pago.cliente_id == uuid.UUID(current_user["id"])
        )
    )
    pago = result.scalar_one_or_none()
    if not pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado")

    # ── Validar imagen ────────────────────────────────────────
    tipos_permitidos = ["image/jpeg", "image/jpg", "image/png", "image/webp"]
    if imagen.content_type not in tipos_permitidos:
        raise HTTPException(status_code=400, detail="Solo JPG, PNG o WEBP")

    imagen_bytes = await imagen.read()
    if len(imagen_bytes) / (1024 * 1024) > 5:
        raise HTTPException(status_code=400, detail="Máximo 5MB")

    # ── Subir a imgbb ─────────────────────────────────────────
    nombre_archivo = f"voucher_{pago_id}"
    if settings.IMGBB_API_KEY and settings.IMGBB_API_KEY != "pendiente":
        voucher_url = await subir_imagen_imgbb(imagen_bytes, nombre_archivo)
    else:
        voucher_url = f"https://placeholder.com/voucher/{pago_id}"

    pago.voucher_url = voucher_url
    pago.estado = EstadoPagoEnum.pendiente

    # ── Notificar al admin ────────────────────────────────────
    reserva_result = await db.execute(
        select(Reserva).where(Reserva.id == pago.reserva_id)
    )
    reserva = reserva_result.scalar_one_or_none()

    if reserva:
        # Obtener nombre del cliente
        cliente_result = await db.execute(
            select(User).where(User.id == uuid.UUID(current_user["id"]))
        )
        cliente = cliente_result.scalar_one_or_none()
        cliente_nombre = cliente.nombre if cliente else "Cliente"

        # Obtener admin del local
        cancha_result = await db.execute(
            select(Cancha).where(Cancha.id == reserva.cancha_id)
        )
        cancha = cancha_result.scalar_one_or_none()

        if cancha:
            admin_result = await db.execute(
                select(User).where(
                    User.rol == "admin",
                    User.activo == True
                ).limit(1)
            )
            admin = admin_result.scalar_one_or_none()

            if admin:
                await notif_reserva_voucher_recibido(
                    db=db,
                    admin_id=admin.id,
                    cliente_nombre=cliente_nombre,
                    codigo=reserva.codigo
                )

    await db.commit()
    await db.refresh(pago)

    return VoucherUploadResponse(
        pago_id=pago.id,
        voucher_url=voucher_url,
        estado=pago.estado.value
    )