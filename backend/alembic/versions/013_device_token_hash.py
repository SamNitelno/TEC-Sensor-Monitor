"""Hash device api_token values; add verification attempt counter."""

import hashlib
import os
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "013"
down_revision: Union[str, None] = "012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _hash_token(plaintext: str, pepper: str) -> str:
    return hashlib.sha256(f"{plaintext}:{pepper}".encode()).hexdigest()


def upgrade() -> None:
    op.add_column(
        "contact_verification_batches",
        sa.Column("failed_attempts", sa.Integer(), nullable=False, server_default="0"),
    )

    pepper = os.environ.get("JWT_SECRET", "")
    if not pepper:
        return

    conn = op.get_bind()
    rows = conn.execute(sa.text("SELECT id, api_token FROM sensors")).fetchall()
    for row in rows:
        token = row.api_token
        if len(token) == 64 and all(c in "0123456789abcdef" for c in token):
            continue
        hashed = _hash_token(token, pepper)
        conn.execute(
            sa.text("UPDATE sensors SET api_token = :hash WHERE id = :id"),
            {"hash": hashed, "id": row.id},
        )


def downgrade() -> None:
    op.drop_column("contact_verification_batches", "failed_attempts")
