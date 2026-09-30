import uuid
from datetime import date, datetime
from pydantic import BaseModel, Field


class LessonCreate(BaseModel):
    topic: str = Field(min_length=1, max_length=240)
    class_id: uuid.UUID | None = None
    subject_id: uuid.UUID
    academic_year_id: uuid.UUID
    curriculum_lesson_id: uuid.UUID | None = None
    lesson_date: date | None = None
    duration_min: int | None = 60
    objectives: str | None = None
    content: str | None = None
    activities: str | None = None
    homework: str | None = None
    notes: str | None = None
    journal_covered: str | None = None
    completion: str = Field(default="planned", pattern="^(planned|in_progress|completed)$")


class LessonUpdate(BaseModel):
    topic: str | None = Field(default=None, min_length=1, max_length=240)
    class_id: uuid.UUID | None = None
    lesson_date: date | None = None
    duration_min: int | None = None
    objectives: str | None = None
    content: str | None = None
    activities: str | None = None
    homework: str | None = None
    notes: str | None = None
    journal_covered: str | None = None
    completion: str | None = Field(default=None, pattern="^(planned|in_progress|completed)$")
    base_version: int = Field(description="Client version for optimistic locking")


class LessonOut(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID | None = None
    subject_id: uuid.UUID
    academic_year_id: uuid.UUID
    curriculum_lesson_id: uuid.UUID | None = None
    topic: str
    lesson_date: date | None = None
    duration_min: int | None = None
    objectives: str | None = None
    content: str | None = None
    activities: str | None = None
    homework: str | None = None
    notes: str | None = None
    journal_covered: str | None = None
    completion: str
    version: int
    created_at: datetime
    updated_at: datetime
