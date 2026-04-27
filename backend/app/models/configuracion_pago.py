import uuid
from sqlalchemy import String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from app.core.database import Base


class ConfiguracionPago(Base):
    """Configuración de medios de pago por admin (yape, plin QR, BCP, BBVA)."""
    __tablename__ = "configuracion_pagos"
    __table_args__ = (
        UniqueConstraint("admin_id", name="uq_configuracion_pago_admin"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    admin_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    yape_numero: Mapped[str | None] = mapped_column(String(15), nullable=True)
    qr_imagen_base64: Mapped[str | None] = mapped_column(Text, nullable=True)
    cuenta_bcp: Mapped[str | None] = mapped_column(String(30), nullable=True)
    cuenta_bbva: Mapped[str | None] = mapped_column(String(30), nullable=True)
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
