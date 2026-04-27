"""add_configuracion_pago_table

Revision ID: i3j4k5l6m7n8
Revises: h2i3j4k5l6m7
Create Date: 2026-04-27

Crea la tabla configuracion_pagos para medios de pago por admin.
"""
from alembic import op
import sqlalchemy as sa
import uuid

revision = 'i3j4k5l6m7n8'
down_revision = 'h2i3j4k5l6m7'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'configuracion_pagos',
        sa.Column('id', sa.Uuid(), nullable=False, default=uuid.uuid4),
        sa.Column('admin_id', sa.Uuid(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('yape_numero', sa.String(15), nullable=True),
        sa.Column('qr_imagen_base64', sa.Text(), nullable=True),
        sa.Column('cuenta_bcp', sa.String(30), nullable=True),
        sa.Column('cuenta_bbva', sa.String(30), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('admin_id', name='uq_configuracion_pago_admin'),
    )


def downgrade() -> None:
    op.drop_table('configuracion_pagos')
