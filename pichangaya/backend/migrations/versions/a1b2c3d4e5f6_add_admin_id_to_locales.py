"""add admin_id to locales

Revision ID: a1b2c3d4e5f6
Revises: 4f4f8043c1a6
Create Date: 2026-03-31
"""
from alembic import op
import sqlalchemy as sa

revision = 'a1b2c3d4e5f6'
down_revision = '4f4f8043c1a6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('locales',
        sa.Column('admin_id', sa.UUID(), nullable=True)
    )
    op.create_foreign_key(
        'fk_locales_admin_id',
        'locales', 'users',
        ['admin_id'], ['id'],
        ondelete='SET NULL'
    )


def downgrade() -> None:
    op.drop_constraint('fk_locales_admin_id', 'locales', type_='foreignkey')
    op.drop_column('locales', 'admin_id')
