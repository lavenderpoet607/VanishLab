from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_async_db, get_current_user
from app.core.config import settings
from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User
from app.schemas.auth import (
    UserRegister,
    UserLogin,
    Token,
    UserResponse,
    QuotaResponse,
)
from app.services.quota import quota_service

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_in: UserRegister, db: AsyncSession = Depends(get_async_db)):
    """Register a new user account with daily quota."""
    existing_user = await db.scalar(select(User).where(User.email == user_in.email))
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email already exists.",
        )

    user = User(
        email=user_in.email,
        hashed_password=hash_password(user_in.password),
        daily_quota=settings.DEFAULT_USER_DAILY_QUOTA,
        used_quota_today=0,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user

@router.post("/login", response_model=Token)
async def login(credentials: UserLogin, db: AsyncSession = Depends(get_async_db)):
    """Authenticate and obtain JWT bearer token."""
    user = await db.scalar(select(User).where(User.email == credentials.email))

    if not user or not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Inactive user account.")

    token = create_access_token(
        subject=user.id,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        extra_claims={"email": user.email},
    )
    return Token(
        access_token=token,
        token_type="bearer",
        expires_in_minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
    )

@router.get("/me", response_model=UserResponse)
async def get_profile(current_user: User = Depends(get_current_user)):
    """Retrieve profile information for currently authenticated user."""
    return current_user

@router.get("/quota", response_model=QuotaResponse)
async def get_quota_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db),
):
    """Check remaining daily quota and reset time."""
    daily_quota, used, remaining, reset_at = await quota_service.get_user_quota_info(db, current_user)
    return QuotaResponse(
        daily_quota=daily_quota,
        used_quota_today=used,
        remaining_quota=remaining,
        reset_at=reset_at,
    )

@router.post("/quota/reset", response_model=QuotaResponse)
async def reset_quota(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db),
):
    """Reset daily quota for the currently authenticated user (useful for testing or manual reset)."""
    daily_quota, used, remaining, reset_at = await quota_service.reset_user_quota(db, current_user)
    return QuotaResponse(
        daily_quota=daily_quota,
        used_quota_today=used,
        remaining_quota=remaining,
        reset_at=reset_at,
    )
