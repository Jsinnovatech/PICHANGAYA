"""add reserva_cancelada_por_cliente notification type

Revision ID: a1b2c3d4e5f6
Revises: 92c71b2d552c
Create Date: 2026-04-08 00:00:00.000000

"""
from typing import Sequence, Union
from alembic import op


revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '92c71b2d552c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Agrega el nuevo valor al enum de PostgreSQL
    # ALTER TYPE es seguro en producción — no bloquea la tabla
    op.execute("""
        ALTER TYPE tiponotificacionenum
        ADD VALUE IF NOT EXISTS 'reserva_cancelada_por_cliente';
    """)


def downgrade() -> None:
    # PostgreSQL no soporta eliminar valores de un enum directamente.
    # En caso de rollback se dejaría el valor — no rompe nada.
    pass
