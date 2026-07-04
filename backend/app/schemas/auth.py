import re
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.models.user import UserRole

_HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")


class LoginRequest(BaseModel):
    login: str
    password: str


class RegisterRequest(BaseModel):
    login: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole


class LoginAvailabilityResponse(BaseModel):
    login: str
    available: bool


class UserProfile(BaseModel):
    id: int
    login: str
    role: UserRole
    email: str | None
    phone: str | None
    promoted_by_user_id: int | None
    created_at: datetime


class ProfileUpdateResponse(BaseModel):
    profile: UserProfile
    access_token: str | None = None


class ProfileUpdateRequest(BaseModel):
    login: str | None = Field(default=None, min_length=3, max_length=64)
    email: str | None = Field(default=None, max_length=255)
    clear_email: bool = False
    phone: str | None = Field(default=None, max_length=32)
    clear_phone: bool = False


class ContactSendCodesRequest(BaseModel):
    login: str | None = Field(default=None, min_length=3, max_length=64)
    email: str | None = Field(default=None, max_length=255)
    clear_email: bool = False
    phone: str | None = Field(default=None, max_length=32)
    clear_phone: bool = False


class ContactSendCodesResponse(BaseModel):
    batch_id: str
    step: str
    destination_masked: str | None = None
    message: str
    profile: UserProfile | None = None
    access_token: str | None = None


class ContactVerifyCodeRequest(BaseModel):
    batch_id: str
    code: str = Field(min_length=4, max_length=8)


class ContactVerifyCodeResponse(BaseModel):
    step: str
    destination_masked: str | None = None
    message: str
    profile: UserProfile | None = None
    access_token: str | None = None


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


class UserListItem(BaseModel):
    id: int
    login: str
    role: UserRole
    email: str | None
    phone: str | None
    promoted_by_user_id: int | None
    created_at: datetime


class PromoteResponse(BaseModel):
    user: UserListItem
    message: str = "User promoted to admin"


class DemoteResponse(BaseModel):
    user: UserListItem
    message: str = "User demoted to viewer"


def validate_hex_color(value: str | None) -> str | None:
    if value is None:
        return None
    if not _HEX_COLOR.match(value):
        raise ValueError("Color must be in #RRGGBB format")
    return value.upper()
