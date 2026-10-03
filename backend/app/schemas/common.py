from typing import Any, Generic, Optional, TypeVar
from pydantic import BaseModel, Field

DataT = TypeVar("DataT")

class StandardResponse(BaseModel, Generic[DataT]):
    status: str = "success"
    message: str = "Operation completed successfully."
    data: Optional[DataT] = None

class ErrorDetail(BaseModel):
    status: str = "error"
    error_code: str
    message: str
    details: Optional[Any] = None
