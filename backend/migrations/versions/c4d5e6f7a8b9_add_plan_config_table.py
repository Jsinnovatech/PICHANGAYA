"""add_plan_config_table

Revision ID: c4d5e6f7a8b9
Revises: b3c4d5e6f7a8
Create Date: 2026-04-15

Crea la tabla plan_config con los 4 planes activos de PichangaYa
e inserta los datos iniciales.
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'c4d5e6f7a8b9'
down_revision: Union[str, None] = 'b3c4d5e6f7a8'
branch_labels: Union[Sequence[str], None] = None
depends_on: Union[Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'plan_config',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('clave', sa.String(20), nullable=False),
        sa.Column('nombre', sa.String(60), nullable=False),
        sa.Column('precio', sa.Numeric(8, 2), nullable=False),
        sa.Column('duracion_dias', sa.Integer(), nullable=False, server_default='30'),
        sa.Column('descripcion', sa.Text(), nullable=True),
        sa.Column('activo', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('clave'),
    )

    # Datos iniciales
    op.execute("""
        INSERT INTO plan_config (clave, nombre, precio, duracion_dias, descripcion, activo) VALUES
        ('free',     'Plan Gratuito',  0.00, 30, 'Hasta 2 canchas. Sin emisión de comprobantes SUNAT.', true),
        ('boleta',   'Plan Boleta',   30.00, 30, 'Boletas electrónicas SUNAT. Canchas ilimitadas.', true),
        ('factura',  'Plan Factura',  50.00, 30, 'Facturas electrónicas SUNAT. Canchas ilimitadas.', true),
        ('completo', 'Plan Completo', 60.00, 30, 'Boletas + Facturas SUNAT. Canchas ilimitadas.', true)
        ON CONFLICT (clave) DO NOTHING;
    """)


def downgrade() -> None:
    op.drop_table('plan_config')
