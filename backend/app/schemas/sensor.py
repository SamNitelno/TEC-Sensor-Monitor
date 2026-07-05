from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator

from app.models.sensor import SensorStatus
from app.schemas.auth import validate_hex_color


class SensorListItem(BaseModel):
    id: int
    name: str
    device_id: str
    site_id: int | None
    status: SensorStatus
    last_seen: datetime | None
    color: str | None = None
    idle_power_threshold_w: float | None = None
    idle_current_threshold_a: float | None = None
    idle_duration_seconds: int | None = None
    notifications_enabled: bool = True
    created_at: datetime | None = None


class SensorDetail(SensorListItem):
    created_at: datetime


class SensorCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    device_id: str = Field(min_length=1, max_length=64)
    site_id: int | None = None
    color: str | None = None

    @field_validator("color")
    @classmethod
    def _color(cls, value: str | None) -> str | None:
        return validate_hex_color(value)


class SensorUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    site_id: int | None = None
    color: str | None = None
    clear_color: bool = False
    idle_power_threshold_w: float | None = Field(default=None, ge=0)
    clear_idle_power_threshold: bool = False
    idle_current_threshold_a: float | None = Field(default=None, ge=0)
    clear_idle_current_threshold: bool = False
    idle_duration_seconds: int | None = Field(default=None, ge=1)
    clear_idle_duration: bool = False
    notifications_enabled: bool | None = None

    @field_validator("color")
    @classmethod
    def _color(cls, value: str | None) -> str | None:
        return validate_hex_color(value)


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
    ingest_url: str
    api_token: str | None = None
    message: str | None = None


class RotateTokenResponse(BaseModel):
    api_token: str
    ingest_url: str
    warning: str = (
        "Новый токен устройства. Сохраните его сейчас — предыдущий токен больше не действует. "
        "Обновите прошивку или BLE-привязку."
    )


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
    power_w: float | None = None


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


class DemoSeedResponse(BaseModel):
    sensors: int
    points: int
    sensor_names: list[str] = Field(default_factory=list)


class SensorPlacementRecord(BaseModel):
    site_id: int | None
    site_name: str | None
    workshop_id: int | None
    workshop_name: str | None
    assigned_at: datetime
    assigned_by_login: str | None


class SensorAuditInfo(BaseModel):
    id: int
    name: str
    device_id: str
    created_at: datetime
    created_by_login: str | None
    current_site_id: int | None
    current_site_name: str | None
    current_workshop_id: int | None
    current_workshop_name: str | None
    color: str | None
    placement_history: list[SensorPlacementRecord] = Field(default_factory=list)
