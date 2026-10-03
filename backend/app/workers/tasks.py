import io
import os
import shutil
import tempfile
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any
from celery import shared_task
from sqlalchemy import select

from app.core.config import settings
from app.core.database import get_sync_db
from app.core.storage import storage_service
from app.models.task import Task, TaskStatus
from app.models.media import MediaFile
from app.services.extractor import extractor_service
from app.services.inpainting import inpainting_engine
from app.services.retention import cleanup_expired_media_sync
from app.services.video_inpainting import video_inpainting_service

logger = logging.getLogger(__name__)

def _update_task_in_db(
    task_id: str,
    status: Optional[TaskStatus] = None,
    progress: Optional[int] = None,
    result_metadata: Optional[Dict[str, Any]] = None,
    error_message: Optional[str] = None,
) -> None:
    """Helper to update Task status in the database during worker execution."""
    with get_sync_db() as db:
        task = db.execute(select(Task).where(Task.id == task_id)).scalar_one_or_none()
        if task:
            if status is not None:
                task.status = status
            if progress is not None:
                task.progress = progress
            if result_metadata is not None:
                task.result_metadata = result_metadata
            if error_message is not None:
                task.error_message = error_message
            db.commit()

def _safe_update_state(self_task, state: str, meta: Dict[str, Any]) -> None:
    """Safely updates Celery state if running in Celery worker, or no-op if in BackgroundTasks."""
    if self_task is not None and hasattr(self_task, "update_state"):
        try:
            self_task.update_state(state=state, meta=meta)
        except Exception:
            pass

@shared_task(bind=True, name="app.workers.tasks.process_media_download")
def process_media_download(
    self,
    task_id: str,
    user_id: Optional[str],
    url: str,
    extract_audio_only: bool = False,
    crop_watermark_bars: bool = False,
    max_resolution: str = "1080p",
) -> Dict[str, Any]:
    """Background worker task for downloading clean media without watermarks."""
    logger.info("Executing process_media_download for task %s, URL: %s", task_id, url)
    _safe_update_state(self, state="PROGRESS", meta={"progress": 5, "message": "Job received by worker"})
    _update_task_in_db(task_id, status=TaskStatus.PROCESSING, progress=5)

    temp_dir = tempfile.mkdtemp(prefix=f"vanish_dl_{task_id}_")

    try:
        def on_progress(percent: int, message: str):
            _safe_update_state(self, state="PROGRESS", meta={"progress": percent, "message": message})
            _update_task_in_db(task_id, progress=percent)

        clean_filepath, metadata = extractor_service.extract_and_clean_video(
            url=url,
            output_dir=temp_dir,
            task_id=task_id,
            extract_audio_only=extract_audio_only,
            crop_watermark_bars=crop_watermark_bars,
            progress_callback=on_progress,
        )

        on_progress(85, "Uploading clean media to cloud storage...")
        filename = os.path.basename(clean_filepath)
        s3_key = f"outputs/{task_id}/{filename}"
        storage_service.upload_file(clean_filepath, s3_key, content_type=metadata["content_type"])

        with get_sync_db() as db:
            media_file = MediaFile(
                task_id=task_id,
                user_id=user_id,
                storage_key=s3_key,
                file_name=filename,
                file_size_bytes=metadata["file_size"],
                content_type=metadata["content_type"],
                is_output=True,
                expires_at=datetime.now(timezone.utc) + timedelta(hours=settings.MEDIA_RETENTION_HOURS),
            )
            db.add(media_file)
            db.commit()

        on_progress(100, "Clean media processed successfully.")
        _update_task_in_db(
            task_id,
            status=TaskStatus.COMPLETED,
            progress=100,
            result_metadata=metadata,
        )

        return {"task_id": task_id, "status": "completed", "metadata": metadata}

    except Exception as exc:
        err_msg = str(exc)
        logger.exception("process_media_download failed for task %s: %s", task_id, err_msg)
        _update_task_in_db(
            task_id,
            status=TaskStatus.FAILED,
            error_message=err_msg,
        )
        _safe_update_state(self, state="FAILURE", meta={"error": err_msg})
        return {"task_id": task_id, "status": "failed", "error": err_msg}

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

@shared_task(bind=True, name="app.workers.tasks.process_image_inpaint")
def process_image_inpaint(
    self,
    task_id: str,
    user_id: Optional[str],
    original_image_key: str,
    mask_image_key: str,
) -> Dict[str, Any]:
    """Background worker task for watermark inpainting using LaMa ONNX engine."""
    logger.info("Executing process_image_inpaint for task %s", task_id)
    _safe_update_state(self, state="PROGRESS", meta={"progress": 10, "message": "Fetching source image and mask..."})
    _update_task_in_db(task_id, status=TaskStatus.PROCESSING, progress=10)

    try:
        image_bytes = storage_service.get_object_bytes(original_image_key)
        mask_bytes = storage_service.get_object_bytes(mask_image_key)

        _safe_update_state(
            self,
            state="PROGRESS",
            meta={"progress": 40, "message": "Removing watermark with LaMa AI model..."},
        )
        _update_task_in_db(task_id, progress=40)

        clean_png_bytes, metadata = inpainting_engine.inpaint(image_bytes, mask_bytes)

        _safe_update_state(
            self,
            state="PROGRESS",
            meta={"progress": 85, "message": "Saving processed image to storage..."},
        )
        _update_task_in_db(task_id, progress=85)

        output_filename = f"clean_inpainted_{task_id}.png"
        output_s3_key = f"outputs/{task_id}/{output_filename}"

        storage_service.upload_file_obj(
            io.BytesIO(clean_png_bytes),
            output_s3_key,
            content_type="image/png",
        )

        with get_sync_db() as db:
            media_file = MediaFile(
                task_id=task_id,
                user_id=user_id,
                storage_key=output_s3_key,
                file_name=output_filename,
                file_size_bytes=len(clean_png_bytes),
                content_type="image/png",
                is_output=True,
                expires_at=datetime.now(timezone.utc) + timedelta(hours=settings.MEDIA_RETENTION_HOURS),
            )
            db.add(media_file)
            db.commit()

        _update_task_in_db(
            task_id,
            status=TaskStatus.COMPLETED,
            progress=100,
            result_metadata=metadata,
        )
        _safe_update_state(self, state="SUCCESS", meta={"progress": 100, "status": "completed"})

        return {"task_id": task_id, "status": "completed", "metadata": metadata}

    except Exception as exc:
        err_msg = str(exc)
        logger.exception("process_image_inpaint failed for task %s: %s", task_id, err_msg)
        _update_task_in_db(
            task_id,
            status=TaskStatus.FAILED,
            error_message=err_msg,
        )
        _safe_update_state(self, state="FAILURE", meta={"error": err_msg})
        return {"task_id": task_id, "status": "failed", "error": err_msg}

@shared_task(bind=True, name="app.workers.tasks.process_video_inpaint")
def process_video_inpaint(
    self,
    task_id: str,
    user_id: Optional[str],
    original_video_key: str,
    corner_preset: Optional[str] = "bottom_right",
    box_x: Optional[int] = None,
    box_y: Optional[int] = None,
    box_w: Optional[int] = None,
    box_h: Optional[int] = None,
    mask_key: Optional[str] = None,
) -> Dict[str, Any]:
    """Background worker task for video watermark inpainting."""
    logger.info("Executing process_video_inpaint for task %s", task_id)
    _safe_update_state(self, state="PROGRESS", meta={"progress": 5, "message": "Fetching source video..."})
    _update_task_in_db(task_id, status=TaskStatus.PROCESSING, progress=5)

    temp_dir = tempfile.mkdtemp(prefix=f"vanish_vid_inpaint_{task_id}_")
    try:
        def on_progress(percent: int, message: str):
            _safe_update_state(self, state="PROGRESS", meta={"progress": percent, "message": message})
            _update_task_in_db(task_id, progress=percent)

        input_video_path = os.path.join(temp_dir, "input_video.mp4")
        output_video_path = os.path.join(temp_dir, f"clean_{task_id}.mp4")
        storage_service.download_file(original_video_key, input_video_path)

        mask_file_path = None
        if mask_key:
            mask_file_path = os.path.join(temp_dir, "mask.png")
            try:
                storage_service.download_file(mask_key, mask_file_path)
            except Exception:
                mask_file_path = None

        metadata = video_inpainting_service.remove_watermark(
            input_video_path=input_video_path,
            output_video_path=output_video_path,
            corner_preset=corner_preset,
            box_x=box_x,
            box_y=box_y,
            box_w=box_w,
            box_h=box_h,
            mask_image_path=mask_file_path,
            progress_callback=on_progress,
        )

        on_progress(95, "Uploading clean video to storage...")
        output_filename = f"clean_{task_id}.mp4"
        output_s3_key = f"outputs/{task_id}/{output_filename}"
        storage_service.upload_file(output_video_path, output_s3_key, content_type="video/mp4")

        with get_sync_db() as db:
            media_file = MediaFile(
                task_id=task_id,
                user_id=user_id,
                storage_key=output_s3_key,
                file_name=output_filename,
                file_size_bytes=metadata["file_size"],
                content_type="video/mp4",
                is_output=True,
                expires_at=datetime.now(timezone.utc) + timedelta(hours=settings.MEDIA_RETENTION_HOURS),
            )
            db.add(media_file)
            db.commit()

        _update_task_in_db(
            task_id,
            status=TaskStatus.COMPLETED,
            progress=100,
            result_metadata=metadata,
        )
        _safe_update_state(self, state="SUCCESS", meta={"progress": 100, "status": "completed"})

        return {"task_id": task_id, "status": "completed", "metadata": metadata}

    except Exception as exc:
        err_msg = str(exc)
        logger.exception("process_video_inpaint failed for task %s: %s", task_id, err_msg)
        _update_task_in_db(
            task_id,
            status=TaskStatus.FAILED,
            error_message=err_msg,
        )
        _safe_update_state(self, state="FAILURE", meta={"error": err_msg})
        return {"task_id": task_id, "status": "failed", "error": err_msg}

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

@shared_task(name="app.workers.tasks.cleanup_expired_media_task")
def cleanup_expired_media_task() -> Dict[str, Any]:
    """Periodic Celery task for automatic media retention cleanup."""
    with get_sync_db() as db:
        return cleanup_expired_media_sync(db)

