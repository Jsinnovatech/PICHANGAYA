import uuid
import enum
from sqlalchemy import String, Numeric, DateTime, ForeignKey, Enum as SAEnum, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base


class MetodoPagoEnum(str, enum.Enum):
    yape = "yape"
    plin = "plin"
    transferencia = "transferencia"
    efectivo = "efectivo"
    tarjeta = "tarjeta"


class EstadoPagoEnum(str, enum.Enum):
    pendiente = "pendiente"
    verificado = "verificado"
    rechazado = "rechazado"


class Pago(Base):
    __tablename__ = "pagos"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    reserva_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("reservas.id"), nullable=False)
    cliente_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    monto: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False)
    metodo: Mapped[MetodoPagoEnum] = mapped_column(SAEnum(MetodoPagoEnum), nullable=False)
    estado: Mapped[EstadoPagoEnum] = mapped_column(SAEnum(EstadoPagoEnum), default=EstadoPagoEnum.pendiente)
    voucher_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    comprobante_ext: Mapped[str | None] = mapped_column(String(60), nullable=True)
    verificado_por: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    verificado_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relaciones
    reserva = relationship("Reserva", back_populates="pago")
    cliente = relationship("User", back_populates="pagos", foreign_keys=[cliente_id])
