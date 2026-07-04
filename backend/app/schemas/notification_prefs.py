from pydantic import BaseModel


class BulkNotificationsRequest(BaseModel):
    enabled: bool


class BulkNotificationsResponse(BaseModel):
    updated: int
