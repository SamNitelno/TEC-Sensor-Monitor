"""Per-sensor idle detection thresholds.

Revision ID: 008
Revises: 007
Create Date: 2026-07-04
"""

from alembic import op
import sqlalchemy as sa

revision = "008"
down_revision = "007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "sensors",
        sa.Column("idle_power_threshold_w", sa.Float(), nullable=True),
    )
    op.add_column(
        "sensors",
        sa.Column("idle_current_threshold_a", sa.Float(), nullable=True),
    )
    op.add_column(
        "sensors",
        sa.Column("idle_duration_seconds", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("sensors", "idle_duration_seconds")
    op.drop_column("sensors", "idle_current_threshold_a")
    op.drop_column("sensors", "idle_power_threshold_w")
