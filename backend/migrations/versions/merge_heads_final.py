"""merge_heads_final

Revision ID: merge_heads_final
Revises: 4f4f8043c1a6, a1b2c3d4e5f6
Create Date: 2026-04-08

Une las dos ramas paralelas:
  - 4f4f8043c1a6 (add_email_to_users)
  - a1b2c3d4e5f6 (add_reserva_cancelada_notif)
"""
from typing import Sequence, Union
from alembic import op


revision: str = 'merge_heads_final'
down_revision: Union[tuple, None] = ('4f4f8043c1a6', 'a1b2c3d4e5f6')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Migración de merge — sin cambios en el esquema.
    # Solo sirve para unir las dos ramas y tener un head único.
    pass


def downgrade() -> None:
    pass
