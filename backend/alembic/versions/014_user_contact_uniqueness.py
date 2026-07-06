"""Unique email/phone constraints and password reset batches.

Revision ID: 014_user_contact_uniqueness
Revises: 013_device_token_hash
"""

import sqlalchemy as sa
from alembic import op

revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("UPDATE users SET email = LOWER(TRIM(email)) WHERE email IS NOT NULL")
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email_lower
        ON users (LOWER(email))
        WHERE email IS NOT NULL
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS ix_users_phone
        ON users (phone)
        WHERE phone IS NOT NULL
        """
    )
    op.create_table(
        "password_reset_batches",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("channel", sa.String(length=16), nullable=False),
        sa.Column("destination", sa.String(length=255), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("failed_attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_password_reset_batches_user_id",
        "password_reset_batches",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_password_reset_batches_user_id", table_name="password_reset_batches")
    op.drop_table("password_reset_batches")
    op.execute("DROP INDEX IF EXISTS ix_users_phone")
    op.execute("DROP INDEX IF EXISTS ix_users_email_lower")
