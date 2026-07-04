"""User profiles, entity colors, sensor audit.

Revision ID: 006
Revises: 005
Create Date: 2026-07-04
"""

from alembic import op
import sqlalchemy as sa

revision = "006"
down_revision = "005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("email", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("phone", sa.String(32), nullable=True))
    op.add_column("users", sa.Column("promoted_by_user_id", sa.Integer(), nullable=True))
    op.add_column("users", sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column(
        "users",
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )
    op.create_foreign_key(
        "users_promoted_by_user_id_fkey",
        "users",
        "users",
        ["promoted_by_user_id"],
        ["id"],
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.add_column("workshops", sa.Column("color", sa.String(7), nullable=True))
    op.add_column("sites", sa.Column("color", sa.String(7), nullable=True))
    op.add_column("sensors", sa.Column("color", sa.String(7), nullable=True))
    op.add_column("sensors", sa.Column("created_by_user_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "sensors_created_by_user_id_fkey",
        "sensors",
        "users",
        ["created_by_user_id"],
        ["id"],
    )

    op.create_table(
        "sensor_placement_history",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("sensor_id", sa.Integer(), sa.ForeignKey("sensors.id"), nullable=False),
        sa.Column("site_id", sa.Integer(), sa.ForeignKey("sites.id"), nullable=True),
        sa.Column(
            "assigned_by_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.Column(
            "assigned_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_sensor_placement_history_sensor_id",
        "sensor_placement_history",
        ["sensor_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_sensor_placement_history_sensor_id", "sensor_placement_history")
    op.drop_table("sensor_placement_history")
    op.drop_constraint("sensors_created_by_user_id_fkey", "sensors", type_="foreignkey")
    op.drop_column("sensors", "created_by_user_id")
    op.drop_column("sensors", "color")
    op.drop_column("sites", "color")
    op.drop_column("workshops", "color")
    op.drop_index("ix_users_email", "users")
    op.drop_constraint("users_promoted_by_user_id_fkey", "users", type_="foreignkey")
    op.drop_column("users", "is_active")
    op.drop_column("users", "updated_at")
    op.drop_column("users", "promoted_by_user_id")
    op.drop_column("users", "phone")
    op.drop_column("users", "email")
