"""merge_all_heads

Revision ID: f0a1b2c3d4e5
Revises: a2b3c4d5e6f7, d5e6f7a8b9c0, e1f2a3b4c5d6
Create Date: 2026-04-22

Une las 3 ramas paralelas en un único head:
  - a2b3c4d5e6f7 (add_admin_id_to_locales)
  - d5e6f7a8b9c0 (add_refresh_jti_to_users)
  - e1f2a3b4c5d6 (add_factura_fields_to_reservas)
"""
from typing import Sequence, Union
from alembic import op


revision: str = 'f0a1b2c3d4e5'
down_revision: Union[tuple, None] = ('a2b3c4d5e6f7', 'd5e6f7a8b9c0', 'e1f2a3b4c5d6')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Migración de merge — sin cambios en el esquema.
    # Solo une las 3 ramas para tener un head único.
    pass


def downgrade() -> None:
    pass
