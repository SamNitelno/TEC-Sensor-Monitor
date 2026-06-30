"""Initial schema with TimescaleDB hypertable for readings."""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

user_role = postgresql.ENUM("admin", "viewer", name="user_role", create_type=False)
sensor_status = postgresql.ENUM("online", "offline", name="sensor_status", create_type=False)
downtime_type = postgresql.ENUM("offline", "idle", name="downtime_type", create_type=False)


def upgrade() -> None:
    with op.get_context().autocommit_block():
        op.execute("CREATE EXTENSION IF NOT EXISTS timescaledb")

    bind = op.get_bind()
    user_role.create(bind, checkfirst=True)
    sensor_status.create(bind, checkfirst=True)
    downtime_type.create(bind, checkfirst=True)

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("login", sa.String(length=64), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("role", user_role, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint("login"),
    )

    op.create_table(
        "sites",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=255), nullable=False),
    )

    op.create_table(
        "workshops",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("site_id", sa.Integer(), sa.ForeignKey("sites.id"), nullable=False),
    )

    op.create_table(
        "sensors",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("device_id", sa.String(length=64), nullable=False),
        sa.Column("api_token", sa.String(length=255), nullable=False),
        sa.Column("workshop_id", sa.Integer(), sa.ForeignKey("workshops.id"), nullable=True),
        sa.Column(
            "status",
            sensor_status,
            server_default="offline",
            nullable=False,
        ),
        sa.Column("last_seen", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint("device_id"),
        sa.UniqueConstraint("api_token"),
    )

    op.create_table(
        "readings",
        sa.Column("time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("sensor_id", sa.Integer(), sa.ForeignKey("sensors.id"), nullable=False),
        sa.Column("current_a", sa.Float(), nullable=False),
        sa.PrimaryKeyConstraint("time", "sensor_id"),
    )

    with op.get_context().autocommit_block():
        op.execute("SELECT create_hypertable('readings', 'time', if_not_exists => TRUE)")

    op.create_index(
        "ix_readings_sensor_id_time_desc",
        "readings",
        ["sensor_id", sa.text("time DESC")],
    )

    op.create_table(
        "downtime_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("sensor_id", sa.Integer(), sa.ForeignKey("sensors.id"), nullable=False),
        sa.Column("type", downtime_type, nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("downtime_events")
    op.drop_index("ix_readings_sensor_id_time_desc", table_name="readings")
    op.drop_table("readings")
    op.drop_table("sensors")
    op.drop_table("workshops")
    op.drop_table("sites")
    op.drop_table("users")

    bind = op.get_bind()
    downtime_type.drop(bind, checkfirst=True)
    sensor_status.drop(bind, checkfirst=True)
    user_role.drop(bind, checkfirst=True)

    with op.get_context().autocommit_block():
        op.execute("DROP EXTENSION IF EXISTS timescaledb")
