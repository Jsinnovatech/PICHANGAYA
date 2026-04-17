import uuid
import enum
from sqlalchemy import String, Numeric, DateTime, ForeignKey, Enum as SAEnum, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base


class PlanEnum(str, enum.Enum):
    free     = "free"
    # Plan gratuito — hasta 2 canchas, sin SUNAT
    boleta   = "boleta"
    # Plan Boleta S/.30/mes — boletas electrónicas SUNAT, canchas ilimitadas
    factura  = "factura"
    # Plan Factura S/.50/mes — facturas electrónicas SUNAT, canchas ilimitadas
    completo = "completo"
    # Plan Completo S/.60/mes — boletas + facturas SUNAT, canchas ilimitadas
    # Valores legacy mantenidos por compatibilidad con registros anteriores
    basico   = "basico"
    premium  = "premium"


class EstadoSuscripcionEnum(str, enum.Enum):
    pendiente  = "pendiente"
    # Admin subió voucher — esperando verificación del super admin
    activo     = "activo"
    # Super admin aprobó el pago — admin puede usar el app completo
    rechazado  = "rechazado"
    # Super admin rechazó el pago — admin debe volver a pagar
    vencido    = "vencido"
    # Pasaron 30 días desde el pago — admin debe renovar


class Suscripcion(Base):
    __tablename__ = "suscripciones"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True, default=uuid.uuid4
    )

    admin_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), nullable=False
    )
    # ID del admin que paga la suscripción
    # FK a users.id — solo admins pueden tener suscripciones

    plan: Mapped[PlanEnum] = mapped_column(
        SAEnum(PlanEnum), nullable=False
    )
    # 'basico' (S/.30) o 'premium' (S/.50)

    monto: Mapped[float] = mapped_column(
        Numeric(8, 2), nullable=False
    )
    # Monto pagado — 30.00 o 50.00 soles

    metodo_pago: Mapped[str] = mapped_column(
        String(20), nullable=False
    )
    # 'yape' | 'plin' | 'transferencia'

    voucher_url: Mapped[str | None] = mapped_column(
        String(500), nullable=True
    )
    # URL de la captura del pago subida a imgbb
    # None hasta que el admin suba la imagen

    estado: Mapped[EstadoSuscripcionEnum] = mapped_column(
        SAEnum(EstadoSuscripcionEnum),
        default=EstadoSuscripcionEnum.pendiente
    )
    # Estado actual de la suscripción

    fecha_pago: Mapped[DateTime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # Fecha cuando el super admin aprueba el pago
    # None hasta que sea aprobado

    fecha_vencimiento: Mapped[DateTime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # fecha_pago + 30 días
    # None hasta que sea aprobado

    verificado_por: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id"), nullable=True
    )
    # ID del super admin que verificó el pago
    # None hasta que sea revisado

    motivo_rechazo: Mapped[str | None] = mapped_column(
        String(300), nullable=True
    )
    # Razón del rechazo — se envía como notificación al admin

    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Relaciones
    admin = relationship(
        "User", back_populates="suscripciones",
        foreign_keys=[admin_id]
    )