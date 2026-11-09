"""changed meal macros to float so they can hold one decimal

Revision ID: c3f1a7d2e9b4
Revises: 902e5734589a
Create Date: 2026-11-08 20:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c3f1a7d2e9b4'
down_revision: Union[str, Sequence[str], None] = '902e5734589a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

MACRO_COLS = ('protein', 'carbs', 'fat', 'calories')


def upgrade() -> None:
    """Upgrade schema."""
    for col in MACRO_COLS:
        op.alter_column(
            'meals',
            col,
            existing_type=sa.Integer(),
            type_=sa.Float(),
            existing_nullable=False,
        )


def downgrade() -> None:
    """Downgrade schema."""
    #rounds any decimals back to whole numbers
    for col in MACRO_COLS:
        op.alter_column(
            'meals',
            col,
            existing_type=sa.Float(),
            type_=sa.Integer(),
            existing_nullable=False,
            postgresql_using=f'round({col})::integer',
        )
