import uuid
from pydantic import BaseModel, Field

EMAIL_REGEX = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"


class RegisterRequest(BaseModel):
    email: str = Field(pattern=EMAIL_REGEX, max_length=254)
    password: str = Field(min_length=8)
    full_name: str = Field(min_length=2, max_length=200)
    school_name: str | None = Field(default=None, max_length=200)
    locale: str = Field(default="ar", pattern="^(ar|fr|en)$")


class LoginRequest(BaseModel):
    email: str = Field(pattern=EMAIL_REGEX, max_length=254)
    password: str
    device_id: str | None = None


class RefreshTokenRequest(BaseModel):
    refresh_token: str
    device_id: str | None = None


class LogoutRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class TeacherProfile(BaseModel):
    id: uuid.UUID
    school_id: uuid.UUID
    school_name: str
    full_name: str
    photo_key: str | None = None
    subjects: list | None = None


class UserOut(BaseModel):
    id: uuid.UUID
    email: str
    locale: str
    teacher: TeacherProfile | None = None


class AuthResponse(BaseModel):
    user: UserOut
    tokens: TokenResponse
