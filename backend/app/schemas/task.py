from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict
from app.models.task import TaskType, TaskStatus

class MediaFileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    file_name: str
    file_size_bytes: int
    content_type: str
    file_type: Optional[str] = None
    is_output: bool
    download_url: Optional[str] = None
    expires_at: datetime
    created_at: datetime

class TaskStatusResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    task_id: str
    task_type: TaskType
    status: TaskStatus
    progress: int
    error_message: Optional[str] = None
    input_params: Optional[Dict[str, Any]] = None
    result_metadata: Optional[Dict[str, Any]] = None
    output_files: List[MediaFileResponse] = []
    created_at: datetime
    updated_at: datetime
