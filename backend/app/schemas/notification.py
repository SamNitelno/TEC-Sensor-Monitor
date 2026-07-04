from datetime import datetime

from pydantic import BaseModel


class NotificationItem(BaseModel):
    id: int
    message: str
    kind: str
    created_at: datetime


class NotificationAckResponse(BaseModel):
    id: int
    read: bool = True


class NotificationCountResponse(BaseModel):
    count: int
