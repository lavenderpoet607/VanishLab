from typing import Optional
import redis.asyncio as aioredis
import redis
from app.core.config import settings

async_redis_client: Optional[aioredis.Redis] = None

async def get_async_redis() -> aioredis.Redis:
    global async_redis_client
    if async_redis_client is None:
        async_redis_client = aioredis.from_url(
            settings.redis_connection_url,
            encoding="utf-8",
            decode_responses=True,
        )
    return async_redis_client

def get_sync_redis() -> redis.Redis:
    return redis.from_url(
        settings.redis_connection_url,
        decode_responses=True,
    )
