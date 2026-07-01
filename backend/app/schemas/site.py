from pydantic import BaseModel, Field


class SiteCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)


class SiteUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=255)


class SiteResponse(BaseModel):
    id: int
    name: str


class WorkshopCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    site_id: int


class WorkshopUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    site_id: int | None = None


class WorkshopResponse(BaseModel):
    id: int
    name: str
    site_id: int
