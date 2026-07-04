"""Contact verification batches for email/phone binding.

Revision ID: 011
Revises: 010
"""

from alembic import op
import sqlalchemy as sa

revision = "011"
down_revision = "010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "contact_verification_batches",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("pending_login", sa.String(length=64), nullable=True),
        sa.Column("pending_email", sa.String(length=255), nullable=True),
        sa.Column("pending_phone", sa.String(length=32), nullable=True),
        sa.Column("clear_email", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("clear_phone", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("email_code_hash", sa.String(length=64), nullable=True),
        sa.Column("phone_code_hash", sa.String(length=64), nullable=True),
        sa.Column("email_verified", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_contact_verification_batches_user_id",
        "contact_verification_batches",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_contact_verification_batches_user_id", table_name="contact_verification_batches")
    op.drop_table("contact_verification_batches")
