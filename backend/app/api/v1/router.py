from fastapi import APIRouter
from app.api.v1.auth import router as auth_router
from app.api.v1.downloader import router as downloader_router
from app.api.v1.inpaint import router as inpaint_router
from app.api.v1.tasks import router as tasks_router

api_v1_router = APIRouter()

api_v1_router.include_router(auth_router)
api_v1_router.include_router(downloader_router)
api_v1_router.include_router(inpaint_router)
api_v1_router.include_router(tasks_router)
