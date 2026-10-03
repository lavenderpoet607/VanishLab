from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field, ConfigDict

class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, description="Password must be at least 8 characters.")

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_minutes: int

class TokenPayload(BaseModel):
    sub: str
    exp: datetime

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    is_active: bool
    daily_quota: int
    used_quota_today: int
    created_at: datetime

class QuotaResponse(BaseModel):
    daily_quota: int
    used_quota_today: int
    remaining_quota: int
    reset_at: datetime
