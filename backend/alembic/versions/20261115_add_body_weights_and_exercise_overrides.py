"""add body weights and user exercise overrides

Revision ID: 20261115
Revises: 90f1964ca395
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "20261115"
down_revision: Union[str, Sequence[str], None] = "90f1964ca395"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "body_weights",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("weight", sa.Float(), nullable=False),
        sa.Column("logged_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "program_exercise_overrides",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_program_id", sa.UUID(), nullable=False),
        sa.Column("exercise_id", sa.UUID(), nullable=False),
        sa.Column("day", sa.Integer(), nullable=False),
        sa.Column("order", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["user_program_id"], ["user_programs.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["exercise_id"], ["exercises.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_program_id", "day", "order"),
    )

def downgrade() -> None:
    op.drop_table("program_exercise_overrides")
    op.drop_table("body_weights")
