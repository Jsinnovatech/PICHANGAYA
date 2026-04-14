import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.notificacion import Notificacion, TipoNotificacionEnum
from app.models.user import User


async def crear_notificacion(
    db: AsyncSession,
    usuario_id: uuid.UUID,
    tipo: TipoNotificacionEnum,
    titulo: str,
    mensaje: str,
    data: dict | None = None
) -> Notificacion:
    """
    Crea una notificación en la BD para un usuario.
    En el futuro aquí también se enviará el push via FCM.
    Por ahora solo guarda en BD — Flutter la lee al hacer polling.
    """
    notif = Notificacion(
        id=uuid.uuid4(),
        usuario_id=usuario_id,
        tipo=tipo,
        titulo=titulo,
        mensaje=mensaje,
        data=data,
        leida=False,
        enviada_push=False
    )
    db.add(notif)
    # No hacemos commit aquí — el caller lo hace junto con su operación
    # Así si algo falla, la notificación tampoco se guarda (atómica)
    return notif


async def notif_suscripcion_voucher_recibido(
    db: AsyncSession,
    admin_nombre: str,
    plan: str,
    super_admin_id: uuid.UUID
):
    """
    Super admin recibe notificación cuando admin sube voucher de suscripción.
    """
    await crear_notificacion(
        db=db,
        usuario_id=super_admin_id,
        tipo=TipoNotificacionEnum.suscripcion_voucher_recibido,
        titulo="Nuevo pago de suscripción",
        mensaje=f"{admin_nombre} subió un voucher de suscripción — Plan {plan.capitalize()}. Verifica el pago.",
        data={"admin_nombre": admin_nombre, "plan": plan}
    )


async def notif_suscripcion_aprobada(
    db: AsyncSession,
    admin_id: uuid.UUID,
    plan: str,
    fecha_vencimiento: str
):
    """
    Admin recibe notificación cuando super admin aprueba su suscripción.
    """
    await crear_notificacion(
        db=db,
        usuario_id=admin_id,
        tipo=TipoNotificacionEnum.suscripcion_aprobada,
        titulo="¡Suscripción activada!",
        mensaje=f"Tu suscripción Plan {plan.capitalize()} está activa hasta el {fecha_vencimiento}. Ya puedes usar todas las funciones.",
        data={"plan": plan, "fecha_vencimiento": fecha_vencimiento}
    )


async def notif_suscripcion_rechazada(
    db: AsyncSession,
    admin_id: uuid.UUID,
    motivo: str
):
    """
    Admin recibe notificación cuando super admin rechaza su pago.
    """
    await crear_notificacion(
        db=db,
        usuario_id=admin_id,
        tipo=TipoNotificacionEnum.suscripcion_rechazada,
        titulo="Pago rechazado",
        mensaje=f"Tu pago de suscripción fue rechazado: {motivo}. Por favor vuelve a intentarlo.",
        data={"motivo": motivo}
    )


async def notif_reserva_nueva(
    db: AsyncSession,
    admin_id: uuid.UUID,
    cliente_nombre: str,
    cancha_nombre: str,
    fecha: str,
    hora: str,
    codigo: str
):
    """
    Admin recibe notificación cuando cliente crea una reserva.
    """
    await crear_notificacion(
        db=db,
        usuario_id=admin_id,
        tipo=TipoNotificacionEnum.reserva_nueva,
        titulo="Nueva reserva",
        mensaje=f"Nueva reserva {codigo} de {cliente_nombre} para {cancha_nombre} el {fecha} a las {hora}.",
        data={"codigo": codigo, "cliente": cliente_nombre, "cancha": cancha_nombre}
    )


async def notif_reserva_voucher_recibido(
    db: AsyncSession,
    admin_id: uuid.UUID,
    cliente_nombre: str,
    codigo: str
):
    """
    Admin recibe notificación cuando cliente sube voucher de pago.
    """
    await crear_notificacion(
        db=db,
        usuario_id=admin_id,
        tipo=TipoNotificacionEnum.reserva_voucher_recibido,
        titulo="Voucher recibido",
        mensaje=f"Voucher de pago recibido de {cliente_nombre} para la reserva {codigo}. Verifica el pago.",
        data={"codigo": codigo, "cliente": cliente_nombre}
    )


async def notif_reserva_confirmada(
    db: AsyncSession,
    cliente_id: uuid.UUID,
    codigo: str,
    fecha: str,
    hora: str,
    cancha_nombre: str
):
    """
    Cliente recibe notificación cuando admin aprueba su pago.
    """
    await crear_notificacion(
        db=db,
        usuario_id=cliente_id,
        tipo=TipoNotificacionEnum.reserva_confirmada,
        titulo="✅ Reserva confirmada",
        mensaje=f"Tu reserva {codigo} está confirmada para el {fecha} a las {hora} en {cancha_nombre}. ¡Nos vemos!",
        data={"codigo": codigo, "fecha": fecha, "hora": hora}
    )


async def notif_reserva_rechazada(
    db: AsyncSession,
    cliente_id: uuid.UUID,
    codigo: str,
    motivo: str
):
    """
    Cliente recibe notificación cuando admin rechaza su pago.
    """
    await crear_notificacion(
        db=db,
        usuario_id=cliente_id,
        tipo=TipoNotificacionEnum.reserva_rechazada,
        titulo="❌ Pago rechazado",
        mensaje=f"Tu pago para la reserva {codigo} fue rechazado: {motivo}. Contacta al local.",
        data={"codigo": codigo, "motivo": motivo}
    )


async def notif_reserva_cancelada_por_cliente(
    db: AsyncSession,
    admin_id: uuid.UUID,
    cliente_nombre: str,
    cancha_nombre: str,
    fecha: str,
    hora: str,
    codigo: str
):
    """
    Admin recibe notificación cuando un cliente cancela su reserva.
    El slot queda libre para nuevas reservas.
    """
    await crear_notificacion(
        db=db,
        usuario_id=admin_id,
        tipo=TipoNotificacionEnum.reserva_cancelada_por_cliente,
        titulo="Reserva cancelada por cliente",
        mensaje=f"{cliente_nombre} canceló la reserva {codigo} en {cancha_nombre} el {fecha} a las {hora}. El horario ya está disponible.",
        data={"codigo": codigo, "cliente": cliente_nombre, "cancha": cancha_nombre, "fecha": fecha, "hora": hora}
    )


async def get_super_admin_id(db: AsyncSession) -> uuid.UUID | None:
    """
    Obtiene el ID del super admin para enviarle notificaciones.
    Se usa cuando necesitamos notificar al super admin pero no tenemos su ID.
    """
    from app.models.user import RolEnum
    result = await db.execute(
        select(User).where(User.rol == RolEnum.super_admin, User.activo == True)
    )
    super_admin = result.scalar_one_or_none()
    return super_admin.id if super_admin else None