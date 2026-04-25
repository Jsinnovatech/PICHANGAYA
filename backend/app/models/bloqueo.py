import uuid
from sqlalchemy import String, Text, Date, Time, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from app.core.database import Base


class BloqueoHorario(Base):
    """Slot bloqueado manualmente por el admin (mantenimiento, evento privado, etc.)."""
    __tablename__ = "bloqueos_horario"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    cancha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("canchas.id"), nullable=False, index=True)
    fecha: Mapped[Date] = mapped_column(Date, nullable=False, index=True)
    hora_inicio: Mapped[Time] = mapped_column(Time, nullable=False)
    hora_fin: Mapped[Time] = mapped_column(Time, nullable=False)
    motivo: Mapped[str | None] = mapped_column(String(200), nullable=True)
    creado_por: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
