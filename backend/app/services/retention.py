import logging
from datetime import datetime, timezone
from typing import Dict, Any
from sqlalchemy import select, delete
from sqlalchemy.orm import Session

from app.core.storage import storage_service
from app.models.media import MediaFile

logger = logging.getLogger(__name__)

def cleanup_expired_media_sync(db: Session) -> Dict[str, Any]:
    """Synchronous cleanup function for Celery Beat scheduled jobs.

    Finds all expired media records, removes corresponding S3 objects,
    and removes the database records.
    """
    now = datetime.now(timezone.utc)
    logger.info("Starting expired media cleanup job at %s", now.isoformat())

    expired_files = db.execute(
        select(MediaFile).where(MediaFile.expires_at <= now)
    ).scalars().all()

    s3_deleted = 0
    db_deleted = 0

    for media in expired_files:
        try:
            storage_service.delete_object(media.storage_key)
            s3_deleted += 1
        except Exception as e:
            logger.warning("Failed to delete S3 key '%s': %s", media.storage_key, e)

        db.delete(media)
        db_deleted += 1

    db.commit()

    orphaned_deleted = storage_service.cleanup_expired_objects()

    result = {
        "timestamp": now.isoformat(),
        "expired_db_records_deleted": db_deleted,
        "s3_objects_deleted": s3_deleted + orphaned_deleted,
    }
    logger.info("Media cleanup completed: %s", result)
    return result
