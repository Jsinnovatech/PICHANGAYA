from sqlalchemy import Integer, String, Text, Numeric, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from app.core.database import Base


class Configuracion(Base):
    __tablename__ = "configuracion"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    razon_social: Mapped[str | None] = mapped_column(String(200), nullable=True)
    ruc: Mapped[str | None] = mapped_column(String(11), nullable=True)
    direccion_fiscal: Mapped[str | None] = mapped_column(Text, nullable=True)
    yape_numero: Mapped[str | None] = mapped_column(String(15), nullable=True)
    plin_numero: Mapped[str | None] = mapped_column(String(15), nullable=True)
    cuenta_bcp: Mapped[str | None] = mapped_column(String(30), nullable=True)
    cuenta_bbva: Mapped[str | None] = mapped_column(String(30), nullable=True)
    radio_busqueda_km: Mapped[float] = mapped_column(Numeric(4, 1), default=1.0)
    nubefact_token: Mapped[str | None] = mapped_column(Text, nullable=True)
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
