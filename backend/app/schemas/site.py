from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.schemas.auth import validate_hex_color


class WorkshopCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    color: str | None = None

    @field_validator("color")
    @classmethod
    def _color(cls, value: str | None) -> str | None:
        return validate_hex_color(value)


class WorkshopUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    color: str | None = None
    clear_color: bool = False
    notifications_enabled: bool | None = None

    @field_validator("color")
    @classmethod
    def _color(cls, value: str | None) -> str | None:
        return validate_hex_color(value)


class WorkshopResponse(BaseModel):
    id: int
    name: str
    color: str | None
    notifications_enabled: bool = True
    created_at: datetime


class SiteCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    workshop_id: int
    color: str | None = None

    @field_validator("color")
    @classmethod
    def _color(cls, value: str | None) -> str | None:
        return validate_hex_color(value)


class SiteUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    workshop_id: int | None = None
    color: str | None = None
    clear_color: bool = False
    notifications_enabled: bool | None = None

    @field_validator("color")
    @classmethod
    def _color(cls, value: str | None) -> str | None:
        return validate_hex_color(value)


class SiteResponse(BaseModel):
    id: int
    name: str
    workshop_id: int
    color: str | None
    notifications_enabled: bool = True
    created_at: datetime
