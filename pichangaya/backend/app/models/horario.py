import uuid
from sqlalchemy import Boolean, Numeric, SmallInteger, Time, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base


class HorarioDisponible(Base):
    __tablename__ = "horarios_disponibles"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    cancha_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("canchas.id"), nullable=False)
    dia_semana: Mapped[int] = mapped_column(SmallInteger, nullable=False)  # 0=Lun..6=Dom
    hora_inicio: Mapped[str] = mapped_column(Time, nullable=False)
    hora_fin: Mapped[str] = mapped_column(Time, nullable=False)
    precio_override: Mapped[float | None] = mapped_column(Numeric(8, 2), nullable=True)
    activo: Mapped[bool] = mapped_column(Boolean, default=True)

    # Relaciones
    cancha = relationship("Cancha", back_populates="horarios")
