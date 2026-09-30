import uuid
from datetime import date, datetime
from pydantic import BaseModel, Field


class AssignmentCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    class_id: uuid.UUID
    subject_id: uuid.UUID
    academic_year_id: uuid.UUID
    due_on: date | None = None


class AssignmentUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    due_on: date | None = None
    base_version: int = Field(description="Client version for optimistic locking")


class AssignmentRecordItem(BaseModel):
    student_id: uuid.UUID
    student_name: str | None = None
    status: str = Field(default="assigned", pattern="^(assigned|completed|missing|excused)$")


class BulkAssignmentRecords(BaseModel):
    records: list[AssignmentRecordItem]


class AssignmentOut(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    subject_id: uuid.UUID
    academic_year_id: uuid.UUID
    title: str
    description: str | None = None
    due_on: date | None = None
    version: int
    created_at: datetime
    updated_at: datetime


class AssignmentRecordOut(BaseModel):
    id: uuid.UUID
    assignment_id: uuid.UUID
    student_id: uuid.UUID
    student_name: str | None = None
    status: str
    version: int
    updated_at: datetime
