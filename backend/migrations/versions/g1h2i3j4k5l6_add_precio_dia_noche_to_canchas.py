"""add_precio_dia_noche_to_canchas

Revision ID: g1h2i3j4k5l6
Revises: f0a1b2c3d4e5
Create Date: 2026-04-26

Agrega columnas precio_dia y precio_noche a la tabla canchas.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'g1h2i3j4k5l6'
down_revision: Union[str, None] = 'f0a1b2c3d4e5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('canchas', sa.Column('precio_dia', sa.Numeric(8, 2), nullable=True))
    op.add_column('canchas', sa.Column('precio_noche', sa.Numeric(8, 2), nullable=True))


def downgrade() -> None:
    op.drop_column('canchas', 'precio_noche')
    op.drop_column('canchas', 'precio_dia')
