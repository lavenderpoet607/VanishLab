from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_async_db
from app.core.exceptions import TaskNotFoundException
from app.core.storage import storage_service
from app.models.task import Task
from app.models.media import MediaFile
from app.schemas.task import TaskStatusResponse, MediaFileResponse

router = APIRouter(prefix="/tasks", tags=["Tasks"])

@router.get(
    "/{task_id}",
    response_model=TaskStatusResponse,
    summary="Get Task Status and Presigned Download URLs",
    description="Polls real-time progress of media downloading or inpainting jobs. Returns presigned S3 URLs upon completion.",
)
async def get_task_status(
    task_id: str,
    request: Request,
    db: AsyncSession = Depends(get_async_db),
):
    task = await db.scalar(
        select(Task)
        .where(Task.id == task_id)
        .options(selectinload(Task.media_files))
    )

    if not task:
        raise TaskNotFoundException(task_id)

    req_base = str(request.base_url).rstrip("/")
    client_base_header = request.headers.get("x-client-base-url")
    if client_base_header and "localhost" not in req_base and "127.0.0.1" not in req_base:
        base_url = req_base
    elif client_base_header:
        base_url = client_base_header.split("/api/v1")[0].rstrip("/")
    else:
        base_url = req_base

    output_files = []
    for media in task.media_files:
        if media.is_output:
            ct = media.content_type or ""
            ft = "video" if "video" in ct else ("audio" if "audio" in ct else "image")

            presigned_url = storage_service.generate_presigned_url(
                key=media.storage_key,
                expire_seconds=3600,
                download_filename=media.file_name,
                base_url=base_url,
            )
            output_files.append(
                MediaFileResponse(
                    id=media.id,
                    file_name=media.file_name,
                    file_size_bytes=media.file_size_bytes,
                    content_type=media.content_type,
                    file_type=ft,
                    is_output=media.is_output,
                    download_url=presigned_url,
                    expires_at=media.expires_at,
                    created_at=media.created_at,
                )
            )

    result_meta = dict(task.result_metadata or {})
    input_params = task.input_params or {}
    if "input_key" in input_params and "input_image_url" not in result_meta:
        result_meta["input_image_url"] = storage_service.generate_presigned_url(
            key=input_params["input_key"],
            base_url=base_url,
        )

    return TaskStatusResponse(
        task_id=task.id,
        task_type=task.task_type,
        status=task.status,
        progress=task.progress,
        error_message=task.error_message,
        input_params=input_params,
        result_metadata=result_meta,
        output_files=output_files,
        created_at=task.created_at,
        updated_at=task.updated_at,
    )
