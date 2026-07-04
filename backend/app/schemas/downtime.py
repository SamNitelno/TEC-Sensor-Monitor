from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class DowntimeTypeParam(str, Enum):
    offline = "offline"
    idle = "idle"


class DowntimeEventItem(BaseModel):
    id: int
    sensor_id: int
    sensor_name: str
    site_id: int | None
    site_name: str | None
    workshop_id: int | None
    workshop_name: str | None
    type: str
    started_at: datetime
    ended_at: datetime | None
    duration_seconds: float | None


class DowntimeEventsResponse(BaseModel):
    events: list[DowntimeEventItem] = Field(default_factory=list)


class DowntimeSummaryItem(BaseModel):
    sensor_id: int
    sensor_name: str
    site_id: int | None
    site_name: str | None
    workshop_id: int | None
    workshop_name: str | None
    offline_seconds: float = 0.0
    idle_seconds: float = 0.0
    total_seconds: float = 0.0


class WorkshopDowntimeSummaryItem(BaseModel):
    workshop_id: int
    workshop_name: str
    offline_seconds: float = 0.0
    idle_seconds: float = 0.0
    total_seconds: float = 0.0


class DowntimeSummaryResponse(BaseModel):
    sensors: list[DowntimeSummaryItem] = Field(default_factory=list)
    workshops: list[WorkshopDowntimeSummaryItem] = Field(default_factory=list)
