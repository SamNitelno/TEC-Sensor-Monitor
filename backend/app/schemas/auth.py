from pydantic import BaseModel

from app.models.user import UserRole


class LoginRequest(BaseModel):
    login: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole


class UserInfo(BaseModel):
    id: int
    login: str
    role: UserRole
