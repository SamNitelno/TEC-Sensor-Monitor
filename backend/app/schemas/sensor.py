from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field

from app.models.sensor import SensorStatus


class SensorListItem(BaseModel):
    id: int
    name: str
    status: SensorStatus


class BucketParam(str, Enum):
    raw = "raw"
    minute = "minute"
    hour = "hour"
    day = "day"


class ReadingPoint(BaseModel):
    time: datetime
    avg: float
    min: float
    max: float


class ReadingsResponse(BaseModel):
    bucket: BucketParam
    points: list[ReadingPoint] = Field(default_factory=list)
