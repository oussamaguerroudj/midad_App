import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class SubjectCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    code: str | None = Field(default=None, max_length=20)


class SubjectOut(BaseModel):
    id: uuid.UUID
    name: str
    code: str | None = None
    version: int


class ClassCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    level: str | None = Field(default=None, max_length=60)
    subject_id: uuid.UUID | None = None
    subject_name: str | None = None
    academic_year_id: uuid.UUID | None = None


class ClassUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    level: str | None = Field(default=None, max_length=60)
    subject_id: uuid.UUID | None = None
    base_version: int = Field(description="Client base version for optimistic locking")


class ClassStudentItem(BaseModel):
    id: uuid.UUID
    first_name: str
    last_name: str
    external_ref: str | None = None


class ClassOut(BaseModel):
    id: uuid.UUID
    name: str
    level: str | None = None
    subject_id: uuid.UUID
    subject_name: str
    academic_year_id: uuid.UUID
    student_count: int = 0
    version: int
    created_at: datetime


class ClassDetailOut(ClassOut):
    students: list[ClassStudentItem] = []
