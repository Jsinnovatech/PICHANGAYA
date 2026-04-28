"""add_configuracion_pago_table

Revision ID: a9b1c2d3e4f5
Revises: f0a1b2c3d4e5
Create Date: 2026-04-27

Crea la tabla configuracion_pagos para almacenar
medios de pago (Yape número, QR base64, cuentas BCP/BBVA) por admin.
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'a9b1c2d3e4f5'
down_revision: Union[str, None] = 'f0a1b2c3d4e5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'configuracion_pagos',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('admin_id', postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('yape_numero', sa.String(15), nullable=True),
        sa.Column('qr_imagen_base64', sa.Text, nullable=True),
        sa.Column('cuenta_bcp', sa.String(30), nullable=True),
        sa.Column('cuenta_bbva', sa.String(30), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=True),
        sa.UniqueConstraint('admin_id', name='uq_configuracion_pago_admin'),
    )


def downgrade() -> None:
    op.drop_table('configuracion_pagos')
