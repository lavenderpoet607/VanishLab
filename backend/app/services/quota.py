import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, Tuple
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import QuotaExceededException
from app.core.redis_client import get_async_redis
from app.models.user import User

logger = logging.getLogger(__name__)

class QuotaService:
    @staticmethod
    async def check_and_consume_quota(
        db: AsyncSession,
        user: Optional[User] = None,
        client_ip: Optional[str] = None,
        cost: int = 1,
    ) -> int:
        """Atomically checks and consumes quota for a registered user or guest IP.

        Raises QuotaExceededException if user exceeds daily quota.
        Returns remaining quota.
        """
        now = datetime.now(timezone.utc)
        today_str = now.strftime("%Y-%m-%d")

        if user:
            last_reset = user.last_quota_reset
            if last_reset is None or (hasattr(last_reset, "date") and last_reset.date() < now.date()):
                user.used_quota_today = 0
                user.last_quota_reset = now
                await db.commit()

        if settings.STANDALONE_MODE:
            if user:
                if user.used_quota_today + cost > user.daily_quota:
                    raise QuotaExceededException("Daily quota exceeded.")
                user.used_quota_today += cost
                await db.commit()
                return max(0, user.daily_quota - user.used_quota_today)
            return max(0, settings.GUEST_DAILY_QUOTA - cost)

        redis = await get_async_redis()

        if user:
            limit = user.daily_quota
            redis_key = f"quota:user:{user.id}:{today_str}"
        else:
            ip_id = client_ip or "anonymous"
            limit = settings.GUEST_DAILY_QUOTA
            redis_key = f"quota:guest:{ip_id}:{today_str}"

        try:
            current_used = await redis.get(redis_key)
            current_val = int(current_used) if current_used else 0

            if current_val + cost > limit:
                logger.warning(
                    "Quota limit reached for key %s (used: %d, limit: %d)",
                    redis_key,
                    current_val,
                    limit,
                )
                raise QuotaExceededException(
                    message=f"Daily limit reached ({limit} requests/day). Please upgrade or try again tomorrow.",
                    details={"limit": limit, "used": current_val, "remaining": 0},
                )

            new_val = await redis.incrby(redis_key, cost)
            if new_val == cost:
                await redis.expire(redis_key, 25 * 3600)

            if user:
                user.used_quota_today = new_val
                await db.commit()

            remaining = max(0, limit - new_val)
            return remaining

        except QuotaExceededException:
            raise
        except Exception as e:
            logger.error("Redis quota check failed, falling back to DB: %s", e)
            if user:
                if user.used_quota_today + cost > user.daily_quota:
                    raise QuotaExceededException("Daily quota exceeded.")
                user.used_quota_today += cost
                await db.commit()
                return max(0, user.daily_quota - user.used_quota_today)
            return 1

    @staticmethod
    async def get_user_quota_info(
        db: AsyncSession,
        user: Optional[User] = None,
        client_ip: Optional[str] = None,
    ) -> Tuple[int, int, int, datetime]:
        """Returns (daily_quota, used_quota_today, remaining_quota, reset_at)."""
        now = datetime.now(timezone.utc)
        tomorrow = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        today_str = now.strftime("%Y-%m-%d")

        if not user:
            limit = settings.GUEST_DAILY_QUOTA
            used = 0
            if not settings.STANDALONE_MODE:
                try:
                    redis = await get_async_redis()
                    ip_id = client_ip or "anonymous"
                    redis_key = f"quota:guest:{ip_id}:{today_str}"
                    current_used = await redis.get(redis_key)
                    if current_used:
                        used = int(current_used)
                except Exception as e:
                    logger.error("Failed to get guest quota from Redis: %s", e)
            remaining = max(0, limit - used)
            return limit, used, remaining, tomorrow

        last_reset = user.last_quota_reset
        if last_reset is None or (hasattr(last_reset, "date") and last_reset.date() < now.date()):
            user.used_quota_today = 0
            user.last_quota_reset = now
            await db.commit()

        used = user.used_quota_today

        if not settings.STANDALONE_MODE:
            try:
                redis = await get_async_redis()
                redis_key = f"quota:user:{user.id}:{today_str}"
                current_used = await redis.get(redis_key)
                if current_used is not None:
                    used = int(current_used)
                    if user.used_quota_today != used:
                        user.used_quota_today = used
                        await db.commit()
                else:
                    if user.used_quota_today != 0:
                        user.used_quota_today = 0
                        await db.commit()
                    used = 0
            except Exception as e:
                logger.error("Failed to get user quota from Redis: %s", e)

        remaining = max(0, user.daily_quota - used)
        return user.daily_quota, used, remaining, tomorrow

    @staticmethod
    async def reset_user_quota(
        db: AsyncSession,
        user: User,
    ) -> Tuple[int, int, int, datetime]:
        """Resets used quota to 0 for the specified user."""
        now = datetime.now(timezone.utc)
        tomorrow = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        today_str = now.strftime("%Y-%m-%d")

        user.used_quota_today = 0
        user.last_quota_reset = now
        await db.commit()

        if not settings.STANDALONE_MODE:
            try:
                redis = await get_async_redis()
                redis_key = f"quota:user:{user.id}:{today_str}"
                await redis.delete(redis_key)
            except Exception as e:
                logger.error("Failed to delete Redis quota key: %s", e)

        return user.daily_quota, 0, user.daily_quota, tomorrow

quota_service = QuotaService()
