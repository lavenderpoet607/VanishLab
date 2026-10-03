from typing import Optional
from pydantic import BaseModel
from app.models.task import TaskStatus

class InpaintTaskResponse(BaseModel):
    task_id: str
    status: TaskStatus
    message: str = "Inpainting task accepted and queued."
    estimated_time_sec: int = 5

class InpaintMetadata(BaseModel):
    width: int
    height: int
    channels: int
    processing_time_ms: float
    model_name: str = "LaMa-ONNX"
