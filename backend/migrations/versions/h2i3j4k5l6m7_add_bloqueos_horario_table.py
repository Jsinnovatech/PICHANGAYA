"""add_bloqueos_horario_table

Revision ID: h2i3j4k5l6m7
Revises: g1h2i3j4k5l6
Create Date: 2026-04-26

Crea la tabla bloqueos_horario si no existe.
(Antes se creaba con un script manual; ahora pasa por Alembic para
garantizar que exista en todos los entornos, incluyendo Railway.)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'h2i3j4k5l6m7'
down_revision: Union[str, None] = 'g1h2i3j4k5l6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Usamos IF NOT EXISTS para que no falle si el script manual ya la creó localmente
    op.execute("""
        CREATE TABLE IF NOT EXISTS bloqueos_horario (
            id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
            cancha_id   UUID        NOT NULL REFERENCES canchas(id),
            fecha       DATE        NOT NULL,
            hora_inicio TIME        NOT NULL,
            hora_fin    TIME        NOT NULL,
            motivo      VARCHAR(200),
            creado_por  UUID        REFERENCES users(id),
            created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        )
    """)
    # Índices para filtros frecuentes
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_bloqueos_horario_cancha_id
        ON bloqueos_horario (cancha_id)
    """)
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_bloqueos_horario_fecha
        ON bloqueos_horario (fecha)
    """)


def downgrade() -> None:
    op.drop_table('bloqueos_horario')
