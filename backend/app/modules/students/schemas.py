import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class StudentCreate(BaseModel):
    first_name: str = Field(min_length=1, max_length=120)
    last_name: str = Field(min_length=1, max_length=120)
    external_ref: str | None = Field(default=None, max_length=64)
    class_id: uuid.UUID | None = None


class StudentUpdate(BaseModel):
    first_name: str | None = Field(default=None, min_length=1, max_length=120)
    last_name: str | None = Field(default=None, min_length=1, max_length=120)
    external_ref: str | None = Field(default=None, max_length=64)
    base_version: int = Field(description="Client base version for optimistic locking")


class EnrolledClassItem(BaseModel):
    id: uuid.UUID
    name: str


class StudentOut(BaseModel):
    id: uuid.UUID
    first_name: str
    last_name: str
    external_ref: str | None = None
    classes: list[EnrolledClassItem] = []
    version: int
    created_at: datetime


class StudentNoteCreate(BaseModel):
    body: str = Field(min_length=1)
    class_id: uuid.UUID | None = None


class StudentNoteOut(BaseModel):
    id: uuid.UUID
    body: str
    class_id: uuid.UUID | None = None
    created_at: datetime


class StudentDetailOut(StudentOut):
    notes: list[StudentNoteOut] = []


class ClassEnrollRequest(BaseModel):
    student_id: uuid.UUID
