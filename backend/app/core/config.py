import os
from functools import lru_cache
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    APP_NAME: str = "VanishLab"
    ENV: str = "development"
    DEBUG: bool = True
    API_V1_PREFIX: str = "/api/v1"
    SECRET_KEY: str = "vanishlab-secret-key-change-in-production-min32chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24

    POSTGRES_SERVER: str = "postgres"
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = "vanishlab"
    POSTGRES_PASSWORD: str = "vanishlab_password"
    POSTGRES_DB: str = "vanishlab_db"
    DATABASE_URL: Optional[str] = None
    DATABASE_URL_SYNC: Optional[str] = None

    STANDALONE_MODE: bool = False

    @property
    def async_database_url(self) -> str:
        if self.STANDALONE_MODE:
            return "sqlite+aiosqlite:///./vanishlab.db"
        if self.DATABASE_URL:
            return self.DATABASE_URL
        return (
            f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
            f"@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    @property
    def sync_database_url(self) -> str:
        if self.STANDALONE_MODE:
            return "sqlite:///./vanishlab.db"
        if self.DATABASE_URL_SYNC:
            return self.DATABASE_URL_SYNC
        return (
            f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
            f"@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: Optional[str] = None
    REDIS_DB: int = 0
    REDIS_URL: Optional[str] = None
    CELERY_BROKER_URL: Optional[str] = None
    CELERY_RESULT_BACKEND: Optional[str] = None

    @property
    def redis_connection_url(self) -> str:
        if self.REDIS_URL:
            return self.REDIS_URL
        auth = f":{self.REDIS_PASSWORD}@" if self.REDIS_PASSWORD else ""
        return f"redis://{auth}{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"

    @property
    def celery_broker(self) -> str:
        if self.CELERY_BROKER_URL:
            return self.CELERY_BROKER_URL
        auth = f":{self.REDIS_PASSWORD}@" if self.REDIS_PASSWORD else ""
        return f"redis://{auth}{self.REDIS_HOST}:{self.REDIS_PORT}/1"

    @property
    def celery_backend(self) -> str:
        if self.CELERY_RESULT_BACKEND:
            return self.CELERY_RESULT_BACKEND
        auth = f":{self.REDIS_PASSWORD}@" if self.REDIS_PASSWORD else ""
        return f"redis://{auth}{self.REDIS_HOST}:{self.REDIS_PORT}/2"

    S3_ENDPOINT_URL: str = "http://minio:9000"
    S3_PUBLIC_ENDPOINT_URL: str = "http://localhost:9000"
    S3_ACCESS_KEY: str = "minioadmin"
    S3_SECRET_KEY: str = "minioadmin"
    S3_BUCKET_NAME: str = "vanishlab-media"
    S3_REGION: str = "us-east-1"
    S3_SECURE: bool = False
    PRESIGNED_URL_EXPIRE_SECONDS: int = 3600

    MEDIA_RETENTION_HOURS: int = 24
    CLEANUP_INTERVAL_MINUTES: int = 60

    DEFAULT_USER_DAILY_QUOTA: int = 50
    GUEST_DAILY_QUOTA: int = 5
    MAX_FILE_SIZE_MB: int = 50
    MAX_IMAGE_DIMENSION: int = 2048

    COOKIES_FILE_PATH: Optional[str] = os.getenv("COOKIES_FILE_PATH", None)
    COOKIES_FROM_BROWSER: Optional[str] = os.getenv("COOKIES_FROM_BROWSER", None)

    LAMA_MODEL_PATH: str = os.getenv(
        "LAMA_MODEL_PATH",
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "models_weights", "big-lama.onnx")
        if os.path.exists(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "models_weights", "big-lama.onnx"))
        else "/app/models_weights/big-lama.onnx",
    )

@lru_cache()
def get_settings() -> Settings:
    return Settings()

settings = get_settings()
