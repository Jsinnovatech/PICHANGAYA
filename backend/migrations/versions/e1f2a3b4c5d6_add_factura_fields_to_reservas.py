"""add_factura_fields_to_reservas

Revision ID: e1f2a3b4c5d6
Revises: merge_heads_final
Create Date: 2026-04-21

Agrega ruc_factura y razon_social a la tabla reservas.
Necesarios para emitir facturas electrónicas via Nubefact.
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'e1f2a3b4c5d6'
down_revision: Union[str, None] = 'merge_heads_final'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('reservas',
        sa.Column('ruc_factura', sa.String(11), nullable=True)
    )
    op.add_column('reservas',
        sa.Column('razon_social', sa.String(200), nullable=True)
    )


def downgrade() -> None:
    op.drop_column('reservas', 'razon_social')
    op.drop_column('reservas', 'ruc_factura')
