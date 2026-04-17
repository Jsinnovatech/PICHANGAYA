"""planes_suscripcion_tres_opciones

Revision ID: b3c4d5e6f7a8
Revises: merge_heads_final
Create Date: 2026-04-14

Agrega los nuevos valores al enum planenum:
  free, boleta, factura, completo
(Los valores basico y premium se mantienen por compatibilidad)
"""
from typing import Sequence, Union
from alembic import op


revision: str = 'b3c4d5e6f7a8'
down_revision: Union[str, None] = 'merge_heads_final'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # PostgreSQL permite ADD VALUE IF NOT EXISTS — no falla si ya existe
    op.execute("ALTER TYPE planenum ADD VALUE IF NOT EXISTS 'free'")
    op.execute("ALTER TYPE planenum ADD VALUE IF NOT EXISTS 'boleta'")
    op.execute("ALTER TYPE planenum ADD VALUE IF NOT EXISTS 'factura'")
    op.execute("ALTER TYPE planenum ADD VALUE IF NOT EXISTS 'completo'")


def downgrade() -> None:
    # PostgreSQL no permite eliminar valores de un enum sin recrearlo.
    # Para hacer downgrade habría que recrear el tipo — omitido en dev.
    pass
