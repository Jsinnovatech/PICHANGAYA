import uuid
# uuid es el módulo de Python para generar IDs únicos
# Ejemplo de UUID: "550e8400-e29b-41d4-a716-446655440000"
# Es mejor que un número entero porque no es predecible

from sqlalchemy import String, Boolean, DateTime, Enum as SAEnum
# String → tipo texto con longitud máxima
# Boolean → True o False
# DateTime → fecha y hora con zona horaria
# Enum → campo que solo acepta valores específicos de una lista

from sqlalchemy.orm import Mapped, mapped_column, relationship
# Mapped → declara el tipo Python del campo
# mapped_column → configura cómo se guarda en la base de datos
# relationship → define la relación con otras tablas

from sqlalchemy.sql import func
# func.now() → genera la fecha/hora actual en el servidor de base de datos
# Es mejor que Python datetime porque usa la hora del servidor, no del cliente

from app.core.database import Base
# Base es la clase padre de todos los modelos
# Al heredar de Base, SQLAlchemy sabe que esta clase es una tabla

import enum
# enum de Python para definir los valores válidos del rol


class RolEnum(str, enum.Enum):
    # str hace que el valor se guarde como texto en la base de datos
    # enum.Enum hace que solo se acepten estos tres valores exactos
    cliente     = "cliente"      # usuario que reserva canchas
    admin       = "admin"        # encargado de un complejo deportivo
    super_admin = "super_admin"  # tú — puede crear admins y ver todo


class User(Base):
    __tablename__ = "users"
    # __tablename__ define el nombre exacto de la tabla en PostgreSQL

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True,   # es la clave primaria — identifica cada fila
        default=uuid.uuid4  # genera un UUID automáticamente al crear un usuario
    )

    celular: Mapped[str] = mapped_column(
        String(15),
        unique=True,    # no pueden existir dos usuarios con el mismo celular
        nullable=False, # es obligatorio — no puede estar vacío
        index=True      # crea un índice para búsquedas rápidas por celular
    )

    nombre: Mapped[str] = mapped_column(
        String(120),
        nullable=False  # obligatorio
    )

    dni: Mapped[str | None] = mapped_column(
        String(15),
        nullable=True   # opcional — se usa para facturas
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False  # obligatorio — se guarda el hash bcrypt, nunca la contraseña real
    )

    rol: Mapped[RolEnum] = mapped_column(
        SAEnum(RolEnum),        # en PostgreSQL crea un tipo ENUM
        default=RolEnum.cliente, # por defecto todo nuevo usuario es cliente
        nullable=False
    )

    fcm_token: Mapped[str | None] = mapped_column(
        String(300),
        nullable=True   # opcional — token de Firebase para notificaciones push
    )

    activo: Mapped[bool] = mapped_column(
        Boolean,
        default=True    # los usuarios nuevos están activos por defecto
    )

    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
        # server_default → PostgreSQL pone la fecha automáticamente al insertar
        # timezone=True → guarda con zona horaria (importante para Perú UTC-5)
    )

    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now()
        # onupdate → PostgreSQL actualiza este campo cada vez que se modifica la fila
    )

    # ── Relaciones con otras tablas ───────────────────────────
    reservas = relationship(
        "Reserva",
        back_populates="cliente"
        # back_populates conecta esta relación con el campo "cliente" en el modelo Reserva
        # Permite hacer: usuario.reservas → lista de todas sus reservas
    )

    pagos = relationship(
        "Pago",
        back_populates="cliente",
        foreign_keys="[Pago.cliente_id]"
        # foreign_keys es necesario porque Pago tiene dos FK a users
        # (cliente_id y verificado_por) — hay que especificar cuál usar
    )

    notificaciones = relationship(
        "Notificacion",
        back_populates="usuario"
        # Permite hacer: usuario.notificaciones → lista de sus notificaciones
    )
    suscripciones = relationship(
        "Suscripcion",
        back_populates="admin",
        foreign_keys="[Suscripcion.admin_id]"
        # Permite hacer: admin.suscripciones → lista de sus suscripciones
        # foreign_keys necesario porque Suscripcion tiene dos FK a users
    )