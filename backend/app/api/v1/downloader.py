import os
import logging
import uuid
from typing import Optional, cast, Any
from fastapi import APIRouter, BackgroundTasks, Depends, Request, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_async_db, get_optional_current_user, get_client_ip
from app.core.config import settings
from app.models.task import Task, TaskType, TaskStatus
from app.models.user import User
from app.schemas.downloader import DownloaderRequest, DownloaderTaskResponse
from app.services.browser_cookies import auto_extract_browser_cookies
from app.services.extractor import _resolve_cookies_file
from app.services.quota import quota_service
from app.workers.tasks import process_media_download

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/downloader", tags=["Downloader"])

@router.get(
    "/cookies/status",
    summary="Check Cookies Configuration Status",
)
async def get_cookies_status():
    cookie_path = _resolve_cookies_file()
    if not cookie_path:
        auto_extract_browser_cookies()
        cookie_path = _resolve_cookies_file()

    if cookie_path and os.path.exists(cookie_path) and os.path.getsize(cookie_path) > 0:
        return {
            "has_cookies": True,
            "path": cookie_path,
            "file_size_bytes": os.path.getsize(cookie_path),
            "status": "ready",
            "auto_extracted": True,
        }
    return {
        "has_cookies": False,
        "path": None,
        "file_size_bytes": 0,
        "status": "not_configured",
    }

@router.post(
    "/cookies/sync",
    summary="Auto Sync Cookies from System Browsers",
)
async def sync_browser_cookies():
    success = auto_extract_browser_cookies()
    cookie_path = _resolve_cookies_file()
    size = os.path.getsize(cookie_path) if (cookie_path and os.path.exists(cookie_path)) else 0
    return {
        "success": success,
        "path": cookie_path,
        "size_bytes": size,
        "status": "synchronized" if success else "no_browser_cookies_found",
    }

@router.post(
    "/cookies/upload",
    summary="Upload cookies.txt for Authenticated Downloads",
)
async def upload_cookies(file: UploadFile = File(...)):
    content = await file.read()
    dest = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "cookies.txt"))
    with open(dest, "wb") as f:
        f.write(content)
    return {
        "success": True,
        "message": "Cookies file uploaded and activated successfully.",
        "path": dest,
        "size_bytes": len(content),
    }

@router.post(
    "/process",
    response_model=DownloaderTaskResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Submit Clean Media Extraction Job",
)
async def process_media_url(
    payload: DownloaderRequest,
    request: Request,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_async_db),
    current_user: Optional[User] = Depends(get_optional_current_user),
):
    client_ip = get_client_ip(request)

    await quota_service.check_and_consume_quota(
        db=db,
        user=current_user,
        client_ip=client_ip,
        cost=1,
    )

    task_id = str(uuid.uuid4())
    user_id = current_user.id if current_user else None

    task_record = Task(
        id=task_id,
        user_id=user_id,
        task_type=TaskType.DOWNLOAD_MEDIA,
        status=TaskStatus.QUEUED,
        progress=0,
        input_params={
            "url": payload.url,
            "extract_audio_only": payload.extract_audio_only,
            "crop_watermark_bars": payload.crop_watermark_bars,
            "max_resolution": payload.max_resolution,
            "client_ip": client_ip,
        },
    )
    db.add(task_record)
    await db.commit()

    if settings.STANDALONE_MODE:
        background_tasks.add_task(
            process_media_download,
            task_id,
            user_id,
            payload.url,
            payload.extract_audio_only,
            payload.crop_watermark_bars,
            payload.max_resolution,
        )
    else:
        try:
            cast(Any, process_media_download).apply_async(
                args=[
                    task_id,
                    user_id,
                    payload.url,
                    payload.extract_audio_only,
                    payload.crop_watermark_bars,
                    payload.max_resolution,
                ],
                task_id=task_id,
            )
        except Exception as exc:
            logger.info("Celery broker not connected (%s). Running via background thread...", exc)
            background_tasks.add_task(
                process_media_download,
                task_id,
                user_id,
                payload.url,
                payload.extract_audio_only,
                payload.crop_watermark_bars,
                payload.max_resolution,
            )

    return DownloaderTaskResponse(
        task_id=task_id,
        status=TaskStatus.QUEUED,
        message="Media extraction job accepted and queued for worker processing.",
        estimated_time_sec=15,
    )
