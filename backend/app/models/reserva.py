import uuid
import enum
from sqlalchemy import String, Text, Numeric, Date, Time, DateTime, ForeignKey, Enum as SAEnum, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base


class EstadoReservaEnum(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    active = "active"
    done = "done"
    canceled = "canceled"


class TipoDocEnum(str, enum.Enum):
    boleta = "boleta"
    factura = "factura"


class Reserva(Base):
    __tablename__ = "reservas"
    __table_args__ = (
        # Evita doble reserva en la misma cancha/fecha/hora
        UniqueConstraint("cancha_id", "fecha", "hora_inicio", name="uq_reserva_slot"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    codigo: Mapped[str] = mapped_column(String(12), unique=True, nullable=False)
    cliente_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    cancha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("canchas.id"), nullable=False)
    fecha: Mapped[Date] = mapped_column(Date, nullable=False)
    hora_inicio: Mapped[Time] = mapped_column(Time, nullable=False)
    hora_fin: Mapped[Time] = mapped_column(Time, nullable=False)
    precio_total: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False)
    estado: Mapped[EstadoReservaEnum] = mapped_column(SAEnum(EstadoReservaEnum), default=EstadoReservaEnum.pending)
    tipo_doc: Mapped[TipoDocEnum | None] = mapped_column(SAEnum(TipoDocEnum), nullable=True)
    notas: Mapped[str | None] = mapped_column(Text, nullable=True)
    timer_inicio: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    timer_fin: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relaciones
    cliente = relationship("User", back_populates="reservas")
    cancha = relationship("Cancha", back_populates="reservas")
    pago = relationship("Pago", back_populates="reserva", uselist=False)
    comprobante = relationship("Comprobante", back_populates="reserva", uselist=False)
