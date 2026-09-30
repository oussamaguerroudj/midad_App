import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field


class DocumentFolderCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    parent_id: uuid.UUID | None = None


class DocumentFolderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    teacher_id: uuid.UUID
    parent_id: uuid.UUID | None
    name: str
    version: int
    created_at: datetime
    updated_at: datetime


class DocumentCreate(BaseModel):
    folder_id: uuid.UUID | None = None
    file_name: str = Field(..., min_length=1, max_length=255)
    mime_type: str = Field(..., max_length=120)
    size_bytes: int = Field(..., ge=0)
    storage_key: str


class DocumentUpdate(BaseModel):
    file_name: str | None = Field(None, min_length=1, max_length=255)
    folder_id: uuid.UUID | None = None


class DocumentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    teacher_id: uuid.UUID
    folder_id: uuid.UUID | None
    file_name: str
    mime_type: str
    size_bytes: int
    storage_key: str
    version: int
    created_at: datetime
    updated_at: datetime
