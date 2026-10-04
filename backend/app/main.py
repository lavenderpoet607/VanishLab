import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api.v1.router import api_v1_router
from app.core.config import settings
from app.core.database import async_engine, init_db
from app.core.exceptions import register_exception_handlers
from app.core.redis_client import get_async_redis
from app.core.storage import storage_service
from app.services.browser_cookies import auto_extract_browser_cookies

logging.basicConfig(
    level=logging.INFO if not settings.DEBUG else logging.DEBUG,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("vanishlab")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing %s in [%s] mode...", settings.APP_NAME, settings.ENV)

    try:
        await init_db()
        logger.info("PostgreSQL database tables initialized.")
    except Exception as e:
        logger.error("Failed to initialize database tables: %s", e)

    try:
        storage_service.ensure_bucket_exists()
        logger.info("Object storage bucket '%s' verified.", settings.S3_BUCKET_NAME)
    except Exception as e:
        logger.warning("Storage bucket verification warning: %s", e)

    if not os.environ.get("VERCEL") and not os.environ.get("AWS_LAMBDA_FUNCTION_NAME"):
        try:
            auto_extract_browser_cookies()
        except Exception as e:
            logger.debug("Startup browser cookie sync encountered: %s", e)

    yield

    logger.info("Shutting down %s...", settings.APP_NAME)
    await async_engine.dispose()
    logger.info("Database engine connections closed.")

app = FastAPI(
    title=f"{settings.APP_NAME} API",
    description="High-Concurrency AI Watermark Remover & Clean Media Downloader Engine",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class VercelPathFixMiddleware:
    """Restores original request path rewritten by Vercel serverless proxy."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope.get("type") == "http":
            headers = dict(scope.get("headers", []))
            matched_path = (
                headers.get(b"x-matched-path")
                or headers.get(b"x-invoke-path")
                or headers.get(b"x-forwarded-uri")
                or headers.get(b"x-real-path")
            )
            if matched_path:
                decoded_path = matched_path.decode("utf-8", errors="ignore").split("?")[0]
                if decoded_path and decoded_path != "/api/index.py":
                    scope["path"] = decoded_path
                    scope["raw_path"] = decoded_path.encode("utf-8")
            elif scope.get("path") == "/api/index.py":
                scope["path"] = "/"
                scope["raw_path"] = b"/"
        await self.app(scope, receive, send)

app.add_middleware(VercelPathFixMiddleware)

register_exception_handlers(app)

import os
from fastapi.staticfiles import StaticFiles

try:
    os.makedirs(storage_service.local_dir, exist_ok=True)
    app.mount("/media", StaticFiles(directory=storage_service.local_dir), name="media")
except Exception as e:
    logger.warning("Could not mount /media directory: %s", e)

app.include_router(api_v1_router, prefix=settings.API_V1_PREFIX)

@app.get("/", tags=["Health"])
async def root():
    return {
        "app": settings.APP_NAME,
        "version": "1.0.0",
        "status": "online",
        "docs": "/docs",
        "health": "/health",
        "api": "/api/v1",
    }

@app.get("/api", tags=["Health"])
@app.get("/api/", tags=["Health"], include_in_schema=False)
@app.get("/api/v1", tags=["Health"])
@app.get("/api/v1/", tags=["Health"], include_in_schema=False)
async def api_root():
    return {
        "app": settings.APP_NAME,
        "version": "1.0.0",
        "status": "online",
        "docs": "/docs",
        "endpoints": {
            "auth_me": "/api/v1/auth/me",
            "auth_login": "/api/v1/auth/login",
            "downloader_process": "/api/v1/downloader/process",
            "inpaint_image": "/api/v1/inpaint/image",
            "inpaint_video": "/api/v1/inpaint/video",
            "task_status": "/api/v1/tasks/{task_id}",
        },
    }

@app.get("/health", tags=["Health"], status_code=status.HTTP_200_OK)
async def health_check():
    health_status = {
        "status": "healthy",
        "services": {
            "database": "unknown",
            "redis": "unknown",
            "storage": "unknown",
        },
    }

    try:
        async with async_engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        health_status["services"]["database"] = "ok"
    except Exception as e:
        health_status["status"] = "degraded"
        health_status["services"]["database"] = f"error: {str(e)}"

    if settings.is_standalone:
        health_status["services"]["redis"] = "standalone_internal_queue"
    else:
        try:
            redis = await get_async_redis()
            pong = await redis.ping()
            health_status["services"]["redis"] = "ok" if pong else "failed"
        except Exception as e:
            health_status["status"] = "degraded"
            health_status["services"]["redis"] = f"error: {str(e)}"

    try:
        storage_service.ensure_bucket_exists()
        health_status["services"]["storage"] = "ok"
    except Exception as e:
        health_status["status"] = "degraded"
        health_status["services"]["storage"] = f"error: {str(e)}"

    return health_status
