"""
Modelo para configurar los medios de pago por admin.
Cada admin tiene una fila (unicidad por admin_id).
"""
import uuid
from sqlalchemy import String, Text, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from sqlalchemy import DateTime

from app.core.database import Base


class ConfiguracionPago(Base):
    __tablename__ = "configuracion_pagos"
    __table_args__ = (
        UniqueConstraint("admin_id", name="uq_configuracion_pago_admin"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    admin_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    yape_numero: Mapped[str | None] = mapped_column(String(15), nullable=True)
    qr_imagen_base64: Mapped[str | None] = mapped_column(Text, nullable=True)
    cuenta_bcp: Mapped[str | None] = mapped_column(String(30), nullable=True)
    cuenta_bbva: Mapped[str | None] = mapped_column(String(30), nullable=True)
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
