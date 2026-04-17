import uuid
from sqlalchemy import String, Boolean, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.core.database import Base
import enum


class RolEnum(str, enum.Enum):
    cliente     = "cliente"
    admin       = "admin"
    super_admin = "super_admin"


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True,
        default=uuid.uuid4
    )

    celular: Mapped[str] = mapped_column(
        String(15),
        unique=True,
        nullable=False,
        index=True
    )

    # ── NUEVO: Email como método principal de login ───────────
    email: Mapped[str | None] = mapped_column(
        String(150),
        unique=True,
        nullable=True,
        # nullable=True para no romper usuarios existentes
        index=True
    )

    nombre: Mapped[str] = mapped_column(
        String(120),
        nullable=False
    )

    dni: Mapped[str | None] = mapped_column(
        String(15),
        nullable=True
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    rol: Mapped[RolEnum] = mapped_column(
        SAEnum(RolEnum),
        default=RolEnum.cliente,
        nullable=False
    )

    fcm_token: Mapped[str | None] = mapped_column(
        String(300),
        nullable=True
    )

    # Hash del refresh token activo — al rotar/logout se invalida el anterior
    refresh_jti: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True
    )

    activo: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )

    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now()
    )

    # ── Relaciones ────────────────────────────────────────────
    reservas = relationship(
        "Reserva",
        back_populates="cliente"
    )

    pagos = relationship(
        "Pago",
        back_populates="cliente",
        foreign_keys="[Pago.cliente_id]"
    )

    notificaciones = relationship(
        "Notificacion",
        back_populates="usuario"
    )

    suscripciones = relationship(
        "Suscripcion",
        back_populates="admin",
        foreign_keys="[Suscripcion.admin_id]"
    )