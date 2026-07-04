from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.sensor import Sensor
    from app.models.workshop import Workshop


class Site(Base):
    __tablename__ = "sites"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    workshop_id: Mapped[int] = mapped_column(ForeignKey("workshops.id"), nullable=False)
    color: Mapped[str | None] = mapped_column(String(7), nullable=True)
    notifications_enabled: Mapped[bool] = mapped_column(
        nullable=False, server_default="true"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    workshop: Mapped["Workshop"] = relationship(back_populates="sites")
    sensors: Mapped[list["Sensor"]] = relationship(back_populates="site")
