"""Remove orphan sites without workshop_id from QA runs.

Revision ID: 005
Revises: 004
Create Date: 2026-07-03
"""

from alembic import op
from sqlalchemy import text

revision = "005"
down_revision = "004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    conn.execute(
        text(
            """
            DELETE FROM sites
            WHERE workshop_id IS NULL
              AND id NOT IN (
                SELECT DISTINCT site_id FROM sensors WHERE site_id IS NOT NULL
              )
            """
        )
    )
    conn.execute(
        text(
            """
            UPDATE sites
            SET workshop_id = (SELECT id FROM workshops ORDER BY id LIMIT 1)
            WHERE workshop_id IS NULL
            """
        )
    )


def downgrade() -> None:
    pass
