import enum
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.downtime_event import DowntimeEvent
    from app.models.reading import Reading
    from app.models.workshop import Workshop


class SensorStatus(str, enum.Enum):
    online = "online"
    offline = "offline"


class Sensor(Base):
    __tablename__ = "sensors"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    device_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    api_token: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    workshop_id: Mapped[int | None] = mapped_column(ForeignKey("workshops.id"), nullable=True)
    status: Mapped[SensorStatus] = mapped_column(
        Enum(SensorStatus, name="sensor_status", native_enum=True),
        nullable=False,
        server_default=SensorStatus.offline.value,
    )
    last_seen: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    workshop: Mapped["Workshop | None"] = relationship(back_populates="sensors")
    readings: Mapped[list["Reading"]] = relationship(back_populates="sensor")
    downtime_events: Mapped[list["DowntimeEvent"]] = relationship(back_populates="sensor")
