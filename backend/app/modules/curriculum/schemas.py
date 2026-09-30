import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class CurriculumUnitCreate(BaseModel):
    subject_id: uuid.UUID
    level: str = Field(min_length=1, max_length=60)
    title: str = Field(min_length=1, max_length=200)
    position: int = Field(default=1, ge=1)


class CurriculumLessonCreate(BaseModel):
    unit_id: uuid.UUID
    title: str = Field(min_length=1, max_length=200)
    position: int = Field(default=1, ge=1)


class CurriculumProgressUpdate(BaseModel):
    class_id: uuid.UUID
    curriculum_lesson_id: uuid.UUID
    academic_year_id: uuid.UUID
    status: str = Field(default="not_started", pattern="^(not_started|in_progress|completed)$")


class CurriculumLessonOut(BaseModel):
    id: uuid.UUID
    unit_id: uuid.UUID
    title: str
    position: int
    progress_status: str = "not_started"


class CurriculumUnitOut(BaseModel):
    id: uuid.UUID
    subject_id: uuid.UUID
    level: str
    title: str
    position: int
    lessons: list[CurriculumLessonOut] = []


class CurriculumProgressOut(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    curriculum_lesson_id: uuid.UUID
    academic_year_id: uuid.UUID
    status: str
    updated_at: datetime
