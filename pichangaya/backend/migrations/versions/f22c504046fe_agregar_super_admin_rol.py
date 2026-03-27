"""agregar_super_admin_rol

Revision ID: f22c504046fe
Revises: 3da5310dd269
Create Date: 2026-03-23 16:29:27.269238

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'f22c504046fe'
down_revision: Union[str, None] = '3da5310dd269'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Agrega el valor 'super_admin' al ENUM rolenum que ya existe en PostgreSQL
    # IF NOT EXISTS evita error si por alguna razón ya existiera el valor
    op.execute("ALTER TYPE rolenum ADD VALUE IF NOT EXISTS 'super_admin'")


def downgrade() -> None:
    # PostgreSQL no permite eliminar valores de un ENUM una vez creados
    # Para revertir habría que recrear toda la tabla, por eso lo dejamos en pass
    pass
