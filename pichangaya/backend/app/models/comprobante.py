import uuid
import enum
from sqlalchemy import String, Integer, Numeric, DateTime, ForeignKey, Text, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base


class TipoComprobanteEnum(str, enum.Enum):
    boleta = "boleta"
    factura = "factura"


class EstadoComprobanteEnum(str, enum.Enum):
    pendiente = "pendiente"
    emitido = "emitido"
    error = "error"


class Comprobante(Base):
    __tablename__ = "comprobantes"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    reserva_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("reservas.id"), nullable=False)
    cliente_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    tipo: Mapped[TipoComprobanteEnum] = mapped_column(SAEnum(TipoComprobanteEnum), nullable=False)
    serie: Mapped[str] = mapped_column(String(5), nullable=False)
    numero: Mapped[int] = mapped_column(Integer, nullable=False)
    subtotal: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False)
    igv: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False)
    total: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False)
    ruc_receptor: Mapped[str | None] = mapped_column(String(15), nullable=True)
    razon_receptor: Mapped[str | None] = mapped_column(String(200), nullable=True)
    nubefact_id: Mapped[str | None] = mapped_column(Text, nullable=True)
    xml_firmado_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    pdf_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    estado: Mapped[EstadoComprobanteEnum] = mapped_column(SAEnum(EstadoComprobanteEnum), default=EstadoComprobanteEnum.pendiente)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relaciones
    reserva = relationship("Reserva", back_populates="comprobante")
