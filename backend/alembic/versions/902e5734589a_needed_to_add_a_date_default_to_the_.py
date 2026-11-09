"""needed to add a date default to the meal table

Revision ID: 902e5734589a
Revises: 6be27128555a
Create Date: 2026-11-08 19:39:08.220335

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '902e5734589a'
down_revision: Union[str, Sequence[str], None] = '6be27128555a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.alter_column(
        'meals',
        'meal_date',
        existing_type=sa.Date(),
        server_default=sa.text('CURRENT_DATE'),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.alter_column(
        'meals',
        'meal_date',
        existing_type=sa.Date(),
        server_default=None,
    )