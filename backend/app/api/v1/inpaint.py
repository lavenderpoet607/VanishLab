import io
import os
import logging
import uuid
from typing import Optional, cast, Any
from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, Request, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_async_db, get_current_user, get_client_ip
from app.core.config import settings
from app.core.exceptions import InvalidFileException
from app.core.storage import storage_service
from app.models.task import Task, TaskType, TaskStatus
from app.models.user import User
from app.schemas.inpaint import InpaintTaskResponse
from app.services.quota import quota_service
from app.workers.tasks import process_image_inpaint, process_video_inpaint

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/inpaint", tags=["Inpainting"])

ALLOWED_IMAGE_TYPES = {"image/png", "image/jpeg", "image/jpg", "image/webp"}

@router.post(
    "/image",
    response_model=InpaintTaskResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Submit AI Watermark Removal / Image Inpainting Job",
    description="Accepts source image and binary mask, staging them to storage and dispatching worker.",
)
async def submit_inpaint_job(
    request: Request,
    background_tasks: BackgroundTasks,
    image: UploadFile = File(..., description="Target image file (PNG, JPG, WebP)"),
    mask: UploadFile = File(..., description="Binary mask indicating watermark area (white=watermark, black=keep)"),
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user),
):
    if image.content_type not in ALLOWED_IMAGE_TYPES:
        raise InvalidFileException(f"Unsupported image type '{image.content_type}'. Allowed: PNG, JPEG, WebP.")
    if mask.content_type not in ALLOWED_IMAGE_TYPES:
        raise InvalidFileException(f"Unsupported mask type '{mask.content_type}'. Allowed: PNG, JPEG, WebP.")

    image_bytes = await image.read()
    mask_bytes = await mask.read()

    max_bytes = settings.MAX_FILE_SIZE_MB * 1024 * 1024
    if len(image_bytes) > max_bytes:
        raise InvalidFileException(f"Image file exceeds maximum allowed size ({settings.MAX_FILE_SIZE_MB}MB).")
    if len(mask_bytes) > max_bytes:
        raise InvalidFileException(f"Mask file exceeds maximum allowed size ({settings.MAX_FILE_SIZE_MB}MB).")

    client_ip = get_client_ip(request)

    await quota_service.check_and_consume_quota(
        db=db,
        user=current_user,
        client_ip=client_ip,
        cost=1,
    )

    task_id = str(uuid.uuid4())
    user_id = current_user.id

    img_s3_key = f"inputs/{task_id}/original_{image.filename}"
    mask_s3_key = f"inputs/{task_id}/mask_{mask.filename}"

    storage_service.upload_file_obj(
        io.BytesIO(image_bytes),
        img_s3_key,
        content_type=image.content_type or "image/png",
    )
    storage_service.upload_file_obj(
        io.BytesIO(mask_bytes),
        mask_s3_key,
        content_type=mask.content_type or "image/png",
    )

    task_record = Task(
        id=task_id,
        user_id=user_id,
        task_type=TaskType.INPAINT_IMAGE,
        status=TaskStatus.QUEUED,
        progress=0,
        input_params={
            "image_filename": image.filename,
            "mask_filename": mask.filename,
            "image_size_bytes": len(image_bytes),
            "mask_size_bytes": len(mask_bytes),
            "input_key": img_s3_key,
        },
    )
    db.add(task_record)
    await db.commit()

    if settings.STANDALONE_MODE:
        background_tasks.add_task(
            process_image_inpaint,
            task_id,
            user_id,
            img_s3_key,
            mask_s3_key,
        )
    else:
        try:
            cast(Any, process_image_inpaint).apply_async(
                args=[task_id, user_id, img_s3_key, mask_s3_key],
                task_id=task_id,
            )
        except Exception as exc:
            logger.info("Celery broker not connected (%s). Running via background thread...", exc)
            background_tasks.add_task(
                process_image_inpaint,
                task_id,
                user_id,
                img_s3_key,
                mask_s3_key,
            )

    return InpaintTaskResponse(
        task_id=task_id,
        status=TaskStatus.QUEUED,
        message="Inpainting task accepted and queued for worker processing.",
        estimated_time_sec=5,
    )

from app.services.video_inpainting import video_inpainting_service

ALLOWED_VIDEO_TYPES = {
    "video/mp4",
    "video/quicktime",
    "video/x-matroska",
    "video/webm",
    "application/octet-stream",
}

@router.post(
    "/video/preview",
    summary="Extract Video Preview Frame and Dimensions",
    description="Extracts resolution, duration, fps, and a clear preview frame for watermark placement.",
)
async def extract_video_preview(
    video: UploadFile = File(..., description="Target video file"),
    timestamp_sec: Optional[float] = Form(0.5, description="Timestamp to extract preview frame from"),
):
    video_bytes = await video.read()
    if len(video_bytes) == 0:
        raise InvalidFileException("Uploaded video file is empty.")

    try:
        preview_data = video_inpainting_service.extract_preview_metadata_and_frame(
            video_bytes=video_bytes,
            timestamp_sec=timestamp_sec or 0.5,
        )
        return preview_data
    except Exception as e:
        logger.error("Failed to extract video preview: %s", e)
        raise InvalidFileException(f"Could not extract preview frame from video: {e}")

@router.post(
    "/video",
    response_model=InpaintTaskResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Submit Video Watermark Removal Job",
    description="Accepts video file, removes corner or rectangular watermark with lossless audio preservation.",
)
async def submit_video_inpaint_job(
    request: Request,
    background_tasks: BackgroundTasks,
    video: UploadFile = File(..., description="Target video file (MP4, MOV, MKV, WebM)"),
    corner_preset: Optional[str] = Form("bottom_right", description="Preset corner: bottom_right, top_right, bottom_left, top_left"),
    box_x: Optional[int] = Form(None, description="Optional bounding box X"),
    box_y: Optional[int] = Form(None, description="Optional bounding box Y"),
    box_w: Optional[int] = Form(None, description="Optional bounding box width"),
    box_h: Optional[int] = Form(None, description="Optional bounding box height"),
    mask: Optional[UploadFile] = File(None, description="Optional custom binary mask image"),
    db: AsyncSession = Depends(get_async_db),
    current_user: User = Depends(get_current_user),
):
    video_bytes = await video.read()
    max_bytes = settings.MAX_FILE_SIZE_MB * 1024 * 1024 * 2
    if len(video_bytes) > max_bytes:
        raise InvalidFileException(f"Video file exceeds maximum allowed size ({settings.MAX_FILE_SIZE_MB * 2}MB).")

    client_ip = get_client_ip(request)
    await quota_service.check_and_consume_quota(
        db=db,
        user=current_user,
        client_ip=client_ip,
        cost=1,
    )

    task_id = str(uuid.uuid4())
    user_id = current_user.id

    video_ext = os.path.splitext(video.filename or "video.mp4")[1].lower() or ".mp4"
    vid_s3_key = f"inputs/{task_id}/source{video_ext}"
    storage_service.upload_bytes(video_bytes, vid_s3_key, content_type=video.content_type or "video/mp4")

    mask_s3_key = None
    if mask and mask.filename:
        mask_bytes = await mask.read()
        if len(mask_bytes) > 0:
            mask_s3_key = f"inputs/{task_id}/mask.png"
            storage_service.upload_bytes(mask_bytes, mask_s3_key, content_type="image/png")

    task_record = Task(
        id=task_id,
        user_id=user_id,
        task_type=TaskType.INPAINT_VIDEO,
        status=TaskStatus.QUEUED,
        progress=0,
        input_params={
            "filename": video.filename,
            "corner_preset": corner_preset,
            "box_x": box_x,
            "box_y": box_y,
            "box_w": box_w,
            "box_h": box_h,
            "has_custom_mask": mask_s3_key is not None,
            "video_size_bytes": len(video_bytes),
            "input_key": vid_s3_key,
        },
    )
    db.add(task_record)
    await db.commit()

    task_args = [
        task_id,
        user_id,
        vid_s3_key,
        corner_preset,
        box_x,
        box_y,
        box_w,
        box_h,
        mask_s3_key,
    ]

    if settings.STANDALONE_MODE:
        background_tasks.add_task(process_video_inpaint, *task_args)
    else:
        try:
            cast(Any, process_video_inpaint).apply_async(
                args=task_args,
                task_id=task_id,
            )
        except Exception as exc:
            logger.info("Celery broker not connected (%s). Running video via background thread...", exc)
            background_tasks.add_task(process_video_inpaint, *task_args)

    return InpaintTaskResponse(
        task_id=task_id,
        status=TaskStatus.QUEUED,
        message="Video watermark removal job accepted and queued.",
        estimated_time_sec=15,
    )
