from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ContactVerificationBatch(Base):
    __tablename__ = "contact_verification_batches"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    pending_login: Mapped[str | None] = mapped_column(String(64), nullable=True)
    pending_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    pending_phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    clear_email: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    clear_phone: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    email_code_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    phone_code_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    email_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    failed_attempts: Mapped[int] = mapped_column(nullable=False, server_default="0")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
