"""Add nullable power_w column to readings hypertable."""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "003"
down_revision: Union[str, None] = "002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "readings",
        sa.Column("power_w", sa.Float(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("readings", "power_w")
