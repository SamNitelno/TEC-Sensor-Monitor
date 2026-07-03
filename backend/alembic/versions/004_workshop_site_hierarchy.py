"""Workshop -> Site -> Sensor hierarchy (sites inside workshops).

Revision ID: 004
Revises: 003
Create Date: 2026-07-03
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("sites", sa.Column("workshop_id", sa.Integer(), nullable=True))
    op.add_column("sensors", sa.Column("site_id", sa.Integer(), nullable=True))

    conn = op.get_bind()

    # First workshop per legacy site keeps the existing site row.
    conn.execute(
        text(
            """
            UPDATE sites s
            SET workshop_id = w.id
            FROM (
                SELECT DISTINCT ON (site_id) id, site_id
                FROM workshops
                ORDER BY site_id, id
            ) w
            WHERE s.id = w.site_id
            """
        )
    )

    # Additional workshops under the same legacy site get dedicated site rows.
    conn.execute(
        text(
            """
            INSERT INTO sites (name, workshop_id)
            SELECT s.name || ' (' || w.name || ')', w.id
            FROM workshops w
            JOIN sites s ON w.site_id = s.id
            WHERE NOT EXISTS (
                SELECT 1 FROM sites s2 WHERE s2.workshop_id = w.id
            )
            """
        )
    )

    conn.execute(
        text(
            """
            UPDATE sensors sen
            SET site_id = (
                SELECT s.id FROM sites s
                WHERE s.workshop_id = sen.workshop_id
                ORDER BY s.id
                LIMIT 1
            )
            WHERE sen.workshop_id IS NOT NULL
            """
        )
    )

    op.drop_constraint("sensors_workshop_id_fkey", "sensors", type_="foreignkey")
    op.drop_column("sensors", "workshop_id")

    op.drop_constraint("workshops_site_id_fkey", "workshops", type_="foreignkey")
    op.drop_column("workshops", "site_id")

    op.create_foreign_key(
        "sites_workshop_id_fkey", "sites", "workshops", ["workshop_id"], ["id"]
    )
    op.create_foreign_key(
        "sensors_site_id_fkey", "sensors", "sites", ["site_id"], ["id"]
    )


def downgrade() -> None:
    op.add_column("workshops", sa.Column("site_id", sa.Integer(), nullable=True))
    op.add_column("sensors", sa.Column("workshop_id", sa.Integer(), nullable=True))

    conn = op.get_bind()
    conn.execute(
        text(
            """
            UPDATE workshops w
            SET site_id = s.id
            FROM sites s
            WHERE s.workshop_id = w.id
            """
        )
    )
    conn.execute(
        text(
            """
            UPDATE sensors sen
            SET workshop_id = s.workshop_id
            FROM sites s
            WHERE sen.site_id = s.id
            """
        )
    )

    op.drop_constraint("sensors_site_id_fkey", "sensors", type_="foreignkey")
    op.drop_column("sensors", "site_id")

    op.drop_constraint("sites_workshop_id_fkey", "sites", type_="foreignkey")
    op.drop_column("sites", "workshop_id")

    op.create_foreign_key(
        "workshops_site_id_fkey", "workshops", "sites", ["site_id"], ["id"]
    )
    op.create_foreign_key(
        "sensors_workshop_id_fkey", "sensors", "workshops", ["workshop_id"], ["id"]
    )
