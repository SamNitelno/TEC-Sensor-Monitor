from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.sensor import Sensor
    from app.models.site import Site
    from app.models.user import User


class SensorPlacementHistory(Base):
    __tablename__ = "sensor_placement_history"

    id: Mapped[int] = mapped_column(primary_key=True)
    sensor_id: Mapped[int] = mapped_column(ForeignKey("sensors.id"), nullable=False)
    site_id: Mapped[int | None] = mapped_column(ForeignKey("sites.id"), nullable=True)
    assigned_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"), nullable=True
    )
    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    sensor: Mapped["Sensor"] = relationship(back_populates="placement_history")
    site: Mapped["Site | None"] = relationship()
    assigned_by: Mapped["User | None"] = relationship()
