"""suscripciones_notificaciones_mejoradas

Revision ID: 92c71b2d552c
Revises: f22c504046fe
Create Date: 2026-03-26 16:25:30.310386

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = '92c71b2d552c'
down_revision: Union[str, None] = 'f22c504046fe'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("""
        DO $$ BEGIN
            CREATE TYPE tiponotificacionenum AS ENUM (
                'suscripcion_voucher_recibido',
                'suscripcion_aprobada',
                'suscripcion_rechazada',
                'suscripcion_por_vencer',
                'reserva_nueva',
                'reserva_voucher_recibido',
                'reserva_confirmada',
                'reserva_rechazada'
            );
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
    """)

    op.execute("""
        ALTER TABLE notificaciones
        ALTER COLUMN tipo TYPE tiponotificacionenum
        USING tipo::tiponotificacionenum
    """)

    op.add_column('notificaciones',
        sa.Column('enviada_push', sa.Boolean(), nullable=False,
                  server_default='false')
    )

    op.execute("""
        DO $$ BEGIN
            CREATE TYPE planenum AS ENUM ('basico', 'premium');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
    """)

    op.execute("""
        DO $$ BEGIN
            CREATE TYPE estadosuscripcionenum AS ENUM (
                'pendiente', 'activo', 'rechazado', 'vencido'
            );
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
    """)

    op.create_table('suscripciones',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('admin_id', sa.UUID(), nullable=False),
        sa.Column('plan', sa.Enum('basico', 'premium',
                  name='planenum', create_type=False), nullable=False),
        sa.Column('monto', sa.Numeric(precision=8, scale=2), nullable=False),
        sa.Column('metodo_pago', sa.String(length=20), nullable=False),
        sa.Column('voucher_url', sa.String(length=500), nullable=True),
        sa.Column('estado', sa.Enum('pendiente', 'activo', 'rechazado', 'vencido',
                  name='estadosuscripcionenum', create_type=False), nullable=True),
        sa.Column('fecha_pago', sa.DateTime(timezone=True), nullable=True),
        sa.Column('fecha_vencimiento', sa.DateTime(timezone=True), nullable=True),
        sa.Column('verificado_por', sa.UUID(), nullable=True),
        sa.Column('motivo_rechazo', sa.String(length=300), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['admin_id'], ['users.id']),
        sa.ForeignKeyConstraint(['verificado_por'], ['users.id']),
        sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('suscripciones')
    op.execute("DROP TYPE IF EXISTS estadosuscripcionenum")
    op.execute("DROP TYPE IF EXISTS planenum")
    op.drop_column('notificaciones', 'enviada_push')
    op.execute("""
        ALTER TABLE notificaciones
        ALTER COLUMN tipo TYPE VARCHAR(40) USING tipo::text
    """)
    op.execute("DROP TYPE IF EXISTS tiponotificacionenum")