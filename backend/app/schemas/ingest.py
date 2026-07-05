from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, BeforeValidator, Field

from app.core.config import settings


class ReadingIn(BaseModel):
    current_a: float = Field(
        ge=settings.ingest_min_current_a,
        le=settings.ingest_max_current_a,
    )
    power_w: float | None = Field(
        default=None,
        ge=settings.ingest_min_power_w,
        le=settings.ingest_max_power_w,
    )
    ts: datetime | None = None


def _normalize_to_list(value: ReadingIn | list[ReadingIn]) -> list[ReadingIn]:
    if isinstance(value, list):
        readings = value
    else:
        readings = [value]
    if len(readings) > settings.ingest_max_batch_size:
        msg = f"Batch size exceeds maximum of {settings.ingest_max_batch_size}"
        raise ValueError(msg)
    return readings


IngestPayload = Annotated[list[ReadingIn], BeforeValidator(_normalize_to_list)]


class IngestResponse(BaseModel):
    accepted: int = Field(ge=0)
