from pydantic import BaseModel, Field


class WorkshopCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)


class WorkshopUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)


class WorkshopResponse(BaseModel):
    id: int
    name: str


class SiteCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    workshop_id: int


class SiteUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    workshop_id: int | None = None


class SiteResponse(BaseModel):
    id: int
    name: str
    workshop_id: int
