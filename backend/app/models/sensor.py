import enum
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, Enum, Float, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.downtime_event import DowntimeEvent
    from app.models.reading import Reading
    from app.models.sensor_placement_history import SensorPlacementHistory
    from app.models.site import Site
    from app.models.user import User


class SensorStatus(str, enum.Enum):
    online = "online"
    offline = "offline"


class Sensor(Base):
    __tablename__ = "sensors"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    device_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    api_token: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    site_id: Mapped[int | None] = mapped_column(ForeignKey("sites.id"), nullable=True)
    color: Mapped[str | None] = mapped_column(String(7), nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"), nullable=True
    )
    status: Mapped[SensorStatus] = mapped_column(
        Enum(SensorStatus, name="sensor_status", native_enum=True),
        nullable=False,
        server_default=SensorStatus.offline.value,
    )
    last_seen: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    idle_power_threshold_w: Mapped[float | None] = mapped_column(Float, nullable=True)
    idle_current_threshold_a: Mapped[float | None] = mapped_column(Float, nullable=True)
    idle_duration_seconds: Mapped[int | None] = mapped_column(nullable=True)
    notifications_enabled: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    site: Mapped["Site | None"] = relationship(back_populates="sensors")
    created_by: Mapped["User | None"] = relationship()
    readings: Mapped[list["Reading"]] = relationship(back_populates="sensor")
    downtime_events: Mapped[list["DowntimeEvent"]] = relationship(back_populates="sensor")
    placement_history: Mapped[list["SensorPlacementHistory"]] = relationship(
        back_populates="sensor"
    )
