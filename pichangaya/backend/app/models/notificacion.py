import uuid
import enum
from sqlalchemy import String, Text, Boolean, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base


class TipoNotificacionEnum(str, enum.Enum):
    # Notificaciones de suscripción
    suscripcion_voucher_recibido  = "suscripcion_voucher_recibido"
    # → Super admin: "Admin X subió voucher de suscripción"
    suscripcion_aprobada          = "suscripcion_aprobada"
    # → Admin: "Tu suscripción está activa hasta [fecha]"
    suscripcion_rechazada         = "suscripcion_rechazada"
    # → Admin: "Tu pago fue rechazado: [motivo]"
    suscripcion_por_vencer        = "suscripcion_por_vencer"
    # → Admin: "Tu suscripción vence en 5 días"

    # Notificaciones de reservas
    reserva_nueva                 = "reserva_nueva"
    # → Admin: "Nueva reserva de [cliente] para [cancha]"
    reserva_voucher_recibido      = "reserva_voucher_recibido"
    # → Admin: "Voucher de pago recibido de [cliente]"
    reserva_confirmada            = "reserva_confirmada"
    # → Cliente: "Tu reserva está confirmada"
    reserva_rechazada             = "reserva_rechazada"
    # → Cliente: "Tu pago fue rechazado"


class Notificacion(Base):
    __tablename__ = "notificaciones"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True, default=uuid.uuid4
    )

    usuario_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), nullable=False
    )
    # Destinatario de la notificación

    tipo: Mapped[TipoNotificacionEnum] = mapped_column(
        SAEnum(TipoNotificacionEnum), nullable=False
    )
    # Tipo de notificación — define el ícono y color en el app

    titulo: Mapped[str] = mapped_column(
        String(100), nullable=False
    )
    # Título corto — aparece en el push notification

    mensaje: Mapped[str] = mapped_column(
        Text, nullable=False
    )
    # Cuerpo del mensaje completo

    data: Mapped[dict | None] = mapped_column(
        JSONB, nullable=True
    )
    # Datos extra en JSON — ej: {"reserva_id": "...", "codigo": "RES-000001"}
    # Flutter los usa para navegar a la pantalla correcta al tocar la notif

    leida: Mapped[bool] = mapped_column(
        Boolean, default=False
    )
    # False = no leída (muestra badge rojo en el app)
    # True = ya fue vista por el usuario

    enviada_push: Mapped[bool] = mapped_column(
        Boolean, default=False
    )
    # True si ya se envió el push notification por FCM
    # False si falló o no se configuró FCM todavía

    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Relaciones
    usuario = relationship("User", back_populates="notificaciones")