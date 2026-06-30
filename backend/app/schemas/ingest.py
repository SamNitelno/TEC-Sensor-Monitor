from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, BeforeValidator, Field


class ReadingIn(BaseModel):
    current_a: float
    ts: datetime | None = None


def _normalize_to_list(value: ReadingIn | list[ReadingIn]) -> list[ReadingIn]:
    if isinstance(value, list):
        return value
    return [value]


IngestPayload = Annotated[list[ReadingIn], BeforeValidator(_normalize_to_list)]


class IngestResponse(BaseModel):
    accepted: int = Field(ge=0)
