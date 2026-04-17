"""add_admin_id_to_locales

Revision ID: a2b3c4d5e6f7
Revises: merge_heads_final
Create Date: 2026-04-16

Agrega admin_id a la tabla locales para poder asociar
cada local a su admin y contar reservas por admin.
"""
from typing import Sequence, Union
import sqlalchemy as sa
from alembic import op


revision: str = 'a2b3c4d5e6f7'
down_revision: Union[str, None] = 'merge_heads_final'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'locales',
        sa.Column('admin_id', sa.UUID(), nullable=True)
    )
    op.create_foreign_key(
        'fk_locales_admin_id',
        'locales', 'users',
        ['admin_id'], ['id'],
        ondelete='SET NULL'
    )
    op.create_index('ix_locales_admin_id', 'locales', ['admin_id'])


def downgrade() -> None:
    op.drop_index('ix_locales_admin_id', table_name='locales')
    op.drop_constraint('fk_locales_admin_id', 'locales', type_='foreignkey')
    op.drop_column('locales', 'admin_id')
