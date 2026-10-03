import enum
from typing import Optional, List, Dict, Any, TYPE_CHECKING
from sqlalchemy import Enum as SQLEnum, ForeignKey, Integer, String, Text, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import TimeStampedModel

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.media import MediaFile

class TaskType(str, enum.Enum):
    DOWNLOAD_MEDIA = "download_media"
    INPAINT_IMAGE = "inpaint_image"
    INPAINT_VIDEO = "inpaint_video"

class TaskStatus(str, enum.Enum):
    QUEUED = "queued"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

class Task(TimeStampedModel):
    __tablename__ = "tasks"

    user_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    task_type: Mapped[TaskType] = mapped_column(
        SQLEnum(TaskType, name="task_type_enum"),
        nullable=False,
        index=True,
    )
    status: Mapped[TaskStatus] = mapped_column(
        SQLEnum(TaskStatus, name="task_status_enum"),
        default=TaskStatus.QUEUED,
        nullable=False,
        index=True,
    )
    progress: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    input_params: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)
    result_metadata: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    user: Mapped[Optional["User"]] = relationship("User", back_populates="tasks")
    media_files: Mapped[List["MediaFile"]] = relationship(
        "MediaFile",
        back_populates="task",
        cascade="all, delete-orphan",
    )
