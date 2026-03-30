import uuid
from sqlalchemy import String, Text, Boolean, Numeric, SmallInteger, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base


class Cancha(Base):
    __tablename__ = "canchas"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    local_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("locales.id"), nullable=False)
    nombre: Mapped[str] = mapped_column(String(80), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text, nullable=True)
    capacidad: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=10)
    precio_hora: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False)
    superficie: Mapped[str | None] = mapped_column(String(50), nullable=True)
    foto_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    activa: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relaciones
    local = relationship("Local", back_populates="canchas")
    horarios = relationship("HorarioDisponible", back_populates="cancha")
    reservas = relationship("Reserva", back_populates="cancha")
