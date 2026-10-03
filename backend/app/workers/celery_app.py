from celery import Celery
from celery.schedules import crontab
from app.core.config import settings

celery_app = Celery(
    "vanishlab_workers",
    broker=settings.celery_broker,
    backend=settings.celery_backend,
    include=["app.workers.tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=600,
    task_soft_time_limit=540,
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=50,
    broker_connection_retry_on_startup=False,
    broker_connection_max_retries=1,
    result_backend_transport_options={
        "max_retries": 1,
        "interval_start": 0,
        "interval_step": 0.2,
        "interval_max": 0.5,
    },
    beat_schedule={
        "cleanup-expired-media-every-hour": {
            "task": "app.workers.tasks.cleanup_expired_media_task",
            "schedule": crontab(minute=0),
        },
    },
)
