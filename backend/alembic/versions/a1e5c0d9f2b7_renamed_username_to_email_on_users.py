"""renamed username to email on the users table and made it long enough for real emails

Revision ID: a1e5c0d9f2b7
Revises: 20261115
Create Date: 2026-11-19

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1e5c0d9f2b7'
down_revision: Union[str, Sequence[str], None] = '20261115'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # rename (not drop/add) so existing rows keep their value; the unique constraint follows the column
    op.alter_column('users', 'username', new_column_name='email',
                    existing_type=sa.String(length=30), type_=sa.String(length=254),
                    existing_nullable=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.alter_column('users', 'email', new_column_name='username',
                    existing_type=sa.String(length=254), type_=sa.String(length=30),
                    existing_nullable=False)
