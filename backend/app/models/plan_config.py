import enum
from sqlalchemy import String, Numeric, Integer, Boolean, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from app.core.database import Base


class PlanConfig(Base):
    __tablename__ = "plan_config"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    clave: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    # Coincide con PlanEnum: 'boleta' | 'factura' | 'completo' | 'free'

    nombre: Mapped[str] = mapped_column(String(60), nullable=False)
    # Nombre legible: "Plan Boleta", "Plan Factura", etc.

    precio: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False, default=0)

    duracion_dias: Mapped[int] = mapped_column(Integer, nullable=False, default=30)

    descripcion: Mapped[str | None] = mapped_column(Text, nullable=True)

    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
