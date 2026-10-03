from typing import Optional, Dict, Any
from pydantic import BaseModel, Field, HttpUrl
from app.models.task import TaskStatus

class DownloaderRequest(BaseModel):
    url: str = Field(..., description="Target video/media URL from supported platforms (TikTok, Instagram, YouTube, etc.)")
    extract_audio_only: bool = Field(False, description="Extract and convert audio only (MP3)")
    crop_watermark_bars: bool = Field(False, description="Crop edge margins if persistent watermarks remain")
    max_resolution: Optional[str] = Field("1080p", description="Target maximum resolution (720p, 1080p, 4k)")

class DownloaderTaskResponse(BaseModel):
    task_id: str
    status: TaskStatus
    message: str = "Media extraction job accepted and queued."
    estimated_time_sec: int = 15
