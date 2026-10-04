import io
import os
import shutil
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any
from urllib.parse import urlparse, urlunparse
import boto3
from botocore.client import Config
from botocore.exceptions import ClientError, EndpointConnectionError

from app.core.config import settings
from app.core.exceptions import StorageServiceException

logger = logging.getLogger(__name__)

class S3StorageService:
    """Production S3 / MinIO storage client with local filesystem fallback for standalone dev."""

    def __init__(self):
        self.endpoint_url = settings.S3_ENDPOINT_URL
        self.public_endpoint_url = settings.S3_PUBLIC_ENDPOINT_URL
        self.bucket_name = settings.S3_BUCKET_NAME
        self.access_key = settings.S3_ACCESS_KEY
        self.secret_key = settings.S3_SECRET_KEY
        self.region = settings.S3_REGION
        import tempfile
        if os.environ.get("VERCEL") or os.environ.get("AWS_LAMBDA_FUNCTION_NAME"):
            self.local_dir = os.path.join(tempfile.gettempdir(), "vanishlab", "storage")
        else:
            self.local_dir = os.path.abspath(os.path.join(os.getcwd(), "data", "storage"))
        try:
            os.makedirs(self.local_dir, exist_ok=True)
        except OSError:
            self.local_dir = os.path.join(tempfile.gettempdir(), "vanishlab", "storage")
            try:
                os.makedirs(self.local_dir, exist_ok=True)
            except OSError:
                pass

        self._s3_available = not settings.is_standalone
        self._client = None

        if self._s3_available:
            try:
                self._client = boto3.client(
                    "s3",
                    endpoint_url=self.endpoint_url,
                    aws_access_key_id=self.access_key,
                    aws_secret_access_key=self.secret_key,
                    region_name=self.region,
                    config=Config(
                        signature_version="s3v4",
                        s3={"addressing_style": "path"},
                        retries={"max_attempts": 2, "mode": "standard"},
                    ),
                )
            except Exception as e:
                logger.warning("Could not initialize S3 client: %s. Using local disk storage.", e)
                self._s3_available = False

    def ensure_bucket_exists(self) -> None:
        """Create bucket if S3 is active, or ensure local storage directory exists."""
        if not self._s3_available or self._client is None:
            try:
                os.makedirs(self.local_dir, exist_ok=True)
            except OSError:
                pass
            logger.info("Local standalone storage ready at: %s", self.local_dir)
            return

        try:
            self._client.head_bucket(Bucket=self.bucket_name)
            logger.info("S3 Bucket '%s' verified.", self.bucket_name)
        except (ClientError, EndpointConnectionError, Exception) as e:
            logger.warning("S3 unreachable (%s). Falling back to local storage.", e)
            self._s3_available = False
            try:
                os.makedirs(self.local_dir, exist_ok=True)
            except OSError:
                pass

    def _get_local_path(self, key: str) -> str:
        full_path = os.path.join(self.local_dir, key.replace("/", os.sep))
        try:
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
        except OSError:
            pass
        return full_path

    def upload_file_obj(
        self,
        file_obj: io.BytesIO,
        key: str,
        content_type: str = "application/octet-stream",
        metadata: Optional[Dict[str, str]] = None,
    ) -> str:
        """Upload in-memory bytes object to S3 or local fallback."""
        if not self._s3_available or self._client is None:
            local_path = self._get_local_path(key)
            with open(local_path, "wb") as f:
                f.write(file_obj.getvalue())
            return key

        try:
            extra_args: Dict[str, Any] = {"ContentType": content_type}
            if metadata:
                extra_args["Metadata"] = metadata

            self._client.upload_fileobj(
                file_obj,
                self.bucket_name,
                key,
                ExtraArgs=extra_args,
            )
            return key
        except Exception as e:
            logger.warning("S3 upload failed (%s). Saving to local disk.", e)
            self._s3_available = False
            local_path = self._get_local_path(key)
            with open(local_path, "wb") as f:
                f.write(file_obj.getvalue())
            return key

    def upload_bytes(
        self,
        data: bytes,
        key: str,
        content_type: str = "application/octet-stream",
        metadata: Optional[Dict[str, str]] = None,
    ) -> str:
        """Upload raw bytes buffer to S3 or local disk storage."""
        return self.upload_file_obj(io.BytesIO(data), key, content_type, metadata)

    def upload_file(
        self,
        local_path: str,
        key: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Upload local file to S3 or copy to local storage directory."""
        if not self._s3_available or self._client is None:
            dest_path = self._get_local_path(key)
            shutil.copy2(local_path, dest_path)
            return key

        try:
            self._client.upload_file(
                local_path,
                self.bucket_name,
                key,
                ExtraArgs={"ContentType": content_type},
            )
            return key
        except Exception as e:
            logger.warning("S3 upload failed (%s). Saving to local disk.", e)
            self._s3_available = False
            dest_path = self._get_local_path(key)
            shutil.copy2(local_path, dest_path)
            return key

    def download_file(self, key: str, local_path: str) -> None:
        """Download file from S3 or read from local storage."""
        if not self._s3_available or self._client is None:
            src = self._get_local_path(key)
            if not os.path.exists(src):
                raise StorageServiceException(f"Local file not found: {key}")
            shutil.copy2(src, local_path)
            return

        try:
            self._client.download_file(self.bucket_name, key, local_path)
        except Exception as e:
            src = self._get_local_path(key)
            if os.path.exists(src):
                shutil.copy2(src, local_path)
            else:
                raise StorageServiceException(f"Download failed: {str(e)}")

    def get_object_bytes(self, key: str) -> bytes:
        """Fetch file bytes directly into memory."""
        if not self._s3_available or self._client is None:
            src = self._get_local_path(key)
            if not os.path.exists(src):
                raise StorageServiceException(f"Local file not found: {key}")
            with open(src, "rb") as f:
                return f.read()

        try:
            response = self._client.get_object(Bucket=self.bucket_name, Key=key)
            return response["Body"].read()
        except Exception as e:
            src = self._get_local_path(key)
            if os.path.exists(src):
                with open(src, "rb") as f:
                    return f.read()
            raise StorageServiceException(f"Read object failed: {str(e)}")

    def generate_presigned_url(
        self,
        key: str,
        expire_seconds: Optional[int] = None,
        download_filename: Optional[str] = None,
        base_url: Optional[str] = None,
    ) -> str:
        """Generate presigned S3 URL or direct local static URL."""
        if not self._s3_available or self._client is None:
            base = (base_url or "http://localhost:8000").rstrip("/")
            return f"{base}/media/{key}"

        expire = expire_seconds or settings.PRESIGNED_URL_EXPIRE_SECONDS
        params = {"Bucket": self.bucket_name, "Key": key}

        if download_filename:
            params["ResponseContentDisposition"] = f'attachment; filename="{download_filename}"'

        try:
            url = self._client.generate_presigned_url(
                ClientMethod="get_object",
                Params=params,
                ExpiresIn=expire,
            )

            if self.public_endpoint_url and self.endpoint_url != self.public_endpoint_url:
                parsed_internal = urlparse(self.endpoint_url)
                parsed_public = urlparse(self.public_endpoint_url)
                parsed_url = urlparse(url)

                if parsed_url.netloc == parsed_internal.netloc:
                    rewritten = parsed_url._replace(
                        scheme=parsed_public.scheme,
                        netloc=parsed_public.netloc,
                    )
                    url = urlunparse(rewritten)

            return str(url)
        except Exception:
            return f"http://localhost:8000/media/{key}"

    def delete_object(self, key: str) -> bool:
        """Delete an object from S3 or local directory."""
        deleted = False
        src = self._get_local_path(key)
        if os.path.exists(src):
            try:
                os.remove(src)
                deleted = True
            except Exception:
                pass

        if self._s3_available and self._client:
            try:
                self._client.delete_object(Bucket=self.bucket_name, Key=key)
                deleted = True
            except Exception:
                pass

        return deleted

    def cleanup_expired_objects(self, retention_hours: Optional[int] = None) -> int:
        """Delete objects older than retention_hours."""
        hours = retention_hours or settings.MEDIA_RETENTION_HOURS
        threshold = datetime.now(timezone.utc) - timedelta(hours=hours)
        deleted_count = 0

        if os.path.exists(self.local_dir):
            for root, _, files in os.walk(self.local_dir):
                for f in files:
                    filepath = os.path.join(root, f)
                    mtime = datetime.fromtimestamp(os.path.getmtime(filepath), tz=timezone.utc)
                    if mtime < threshold:
                        try:
                            os.remove(filepath)
                            deleted_count += 1
                        except Exception:
                            pass

        return deleted_count

storage_service = S3StorageService()
