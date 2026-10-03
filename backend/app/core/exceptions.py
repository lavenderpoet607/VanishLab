from typing import Any, Optional
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

class VanishLabException(Exception):
    """Base exception for all VanishLab custom domain exceptions."""

    def __init__(
        self,
        message: str,
        error_code: str = "INTERNAL_SERVER_ERROR",
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        details: Optional[Any] = None,
    ):
        self.message = message
        self.error_code = error_code
        self.status_code = status_code
        self.details = details
        super().__init__(message)

class QuotaExceededException(VanishLabException):
    def __init__(self, message: str = "Daily quota exceeded. Please upgrade or try again tomorrow.", details: Optional[Any] = None):
        super().__init__(
            message=message,
            error_code="QUOTA_EXCEEDED",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            details=details,
        )

class ExtractionFailedException(VanishLabException):
    def __init__(self, message: str = "Media extraction failed. The URL may be invalid, private, or unsupported.", details: Optional[Any] = None):

        status_code = getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", 422)
        super().__init__(
            message=message,
            error_code="EXTRACTION_FAILED",
            status_code=status_code,
            details=details,
        )

class InpaintingFailedException(VanishLabException):
    def __init__(self, message: str = "Image inpainting processing failed.", details: Optional[Any] = None):
        super().__init__(
            message=message,
            error_code="INPAINTING_FAILED",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            details=details,
        )

class StorageServiceException(VanishLabException):
    def __init__(self, message: str = "Storage operation failed.", details: Optional[Any] = None):
        super().__init__(
            message=message,
            error_code="STORAGE_ERROR",
            status_code=status.HTTP_502_BAD_GATEWAY,
            details=details,
        )

class TaskNotFoundException(VanishLabException):
    def __init__(self, task_id: str):
        super().__init__(
            message=f"Task with ID '{task_id}' was not found.",
            error_code="TASK_NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND,
        )

class InvalidFileException(VanishLabException):
    def __init__(self, message: str = "Invalid file uploaded.", details: Optional[Any] = None):
        super().__init__(
            message=message,
            error_code="INVALID_FILE",
            status_code=status.HTTP_400_BAD_REQUEST,
            details=details,
        )

class UnauthorizedException(VanishLabException):
    def __init__(self, message: str = "Authentication credentials were invalid or missing."):
        super().__init__(
            message=message,
            error_code="UNAUTHORIZED",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(VanishLabException)
    async def vanishlab_exception_handler(request: Request, exc: VanishLabException):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "status": "error",
                "error_code": exc.error_code,
                "message": exc.message,
                "details": exc.details,
            },
        )
