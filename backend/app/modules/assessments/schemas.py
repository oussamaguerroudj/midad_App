import uuid
from datetime import date
from pydantic import BaseModel, Field


class AssessmentCreate(BaseModel):
    class_id: uuid.UUID
    title: str = Field(min_length=1, max_length=200)
    kind: str = Field(default="test", pattern="^(homework|assignment|quiz|test|exam|project|participation|custom)$")
    assessed_on: date
    max_score: float = Field(default=20.0, gt=0)
    coefficient: float = Field(default=1.0, gt=0)


class AssessmentOut(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    title: str
    kind: str
    assessed_on: date
    max_score: float
    coefficient: float
    version: int


class ResultEntryIn(BaseModel):
    student_id: uuid.UUID
    score: float | None = Field(default=None, ge=0)
    status: str = Field(default="graded", pattern="^(graded|absent|excused|pending)$")


class ResultEntryOut(BaseModel):
    id: uuid.UUID
    assessment_id: uuid.UUID
    student_id: uuid.UUID
    student_name: str
    score: float | None = None
    status: str
    version: int


class AssessmentDetailOut(AssessmentOut):
    results: list[ResultEntryOut] = []


class ResultsBulkSaveRequest(BaseModel):
    results: list[ResultEntryIn]
