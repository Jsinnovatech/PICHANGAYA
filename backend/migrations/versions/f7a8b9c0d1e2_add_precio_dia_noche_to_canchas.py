"""add_precio_dia_noche_to_canchas

Revision ID: f7a8b9c0d1e2
Revises: a9b1c2d3e4f5
Create Date: 2026-04-29

Agrega precio_dia y precio_noche directamente a la tabla canchas para que
el precio configurado por el admin se persista sin depender de que existan
registros en horarios_disponibles. Solución universal para todos los admins.
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'f7a8b9c0d1e2'
down_revision: Union[str, None] = 'a9b1c2d3e4f5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('canchas', sa.Column('precio_dia',   sa.Numeric(8, 2), nullable=True))
    op.add_column('canchas', sa.Column('precio_noche', sa.Numeric(8, 2), nullable=True))


def downgrade() -> None:
    op.drop_column('canchas', 'precio_noche')
    op.drop_column('canchas', 'precio_dia')
