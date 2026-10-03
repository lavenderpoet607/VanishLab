import logging
from typing import Any
from collections.abc import AsyncGenerator, Generator
from contextlib import contextmanager
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import settings

logger = logging.getLogger(__name__)

is_sqlite_async = "sqlite" in settings.async_database_url
is_sqlite_sync = "sqlite" in settings.sync_database_url

async_engine_kwargs: dict[str, Any] = {
    "echo": settings.DEBUG and settings.ENV == "development",
    "future": True,
}
if not is_sqlite_async:
    async_engine_kwargs["pool_pre_ping"] = True
    async_engine_kwargs["pool_size"] = 20
    async_engine_kwargs["max_overflow"] = 10

sync_engine_kwargs: dict[str, Any] = {
    "echo": False,
    "future": True,
}
if not is_sqlite_sync:
    sync_engine_kwargs["pool_pre_ping"] = True
    sync_engine_kwargs["pool_size"] = 10
    sync_engine_kwargs["max_overflow"] = 5

async_engine = create_async_engine(
    settings.async_database_url,
    **async_engine_kwargs,
)

AsyncSessionLocal = async_sessionmaker(
    bind=async_engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
    class_=AsyncSession,
)

sync_engine = create_engine(
    settings.sync_database_url,
    **sync_engine_kwargs,
)

SyncSessionLocal = sessionmaker(
    bind=sync_engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)

from app.models.base import Base

async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency for obtaining an asynchronous database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

@contextmanager
def get_sync_db() -> Generator:
    """Context manager for Celery workers to obtain a synchronous database session."""
    session = SyncSessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()

async def init_db() -> None:
    """Initialize database tables during application startup."""
    import app.models

    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database initialized successfully with metadata tables.")
