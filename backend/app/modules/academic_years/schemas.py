import uuid
from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field


class AcademicYearCreate(BaseModel):
    label: str = Field(..., max_length=20, examples=["2026-2027"])
    starts_on: date
    ends_on: date
    is_current: bool = False
    school_id: uuid.UUID | None = None


class AcademicYearUpdate(BaseModel):
    label: str | None = Field(None, max_length=20)
    starts_on: date | None = None
    ends_on: date | None = None
    is_current: bool | None = None


class AcademicYearOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    teacher_id: uuid.UUID
    school_id: uuid.UUID
    label: str
    starts_on: date
    ends_on: date
    is_current: bool
    version: int
    created_at: datetime
    updated_at: datetime
