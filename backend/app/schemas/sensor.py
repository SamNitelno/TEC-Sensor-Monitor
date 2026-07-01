from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field

from app.models.sensor import SensorStatus


class SensorListItem(BaseModel):
    id: int
    name: str
    device_id: str
    workshop_id: int | None
    status: SensorStatus
    last_seen: datetime | None


class SensorDetail(SensorListItem):
    created_at: datetime


class SensorCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    device_id: str = Field(min_length=1, max_length=64)
    workshop_id: int | None = None


class SensorUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    workshop_id: int | None = None


class IntegrationSnippet(BaseModel):
    method: str = "POST"
    url: str
    headers: dict[str, str]
    body_schema: dict[str, str]
    body_example: dict[str, float]
    curl: str


class SensorCreateResponse(BaseModel):
    sensor: SensorDetail
    api_token: str
    warning: str = (
        "Токен устройства показывается только один раз. Сохраните его сейчас — "
        "повторно получить через API нельзя."
    )
    integration: IntegrationSnippet


class ProvisioningTokenResponse(BaseModel):
    api_token: str
    ingest_url: str


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


class SensorSeries(BaseModel):
    sensor_id: int
    sensor_name: str
    bucket: BucketParam
    points: list[ReadingPoint] = Field(default_factory=list)


class GroupedReadingsResponse(BaseModel):
    series: list[SensorSeries] = Field(default_factory=list)
