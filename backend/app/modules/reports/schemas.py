from __future__ import annotations

import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict



class AuditLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    actor_user_id: uuid.UUID
    action: str
    entity_type: str
    entity_id: uuid.UUID | None = None
    before: dict | None = None
    after: dict | None = None
    occurred_at: datetime


class FollowUpAlertOut(BaseModel):
    id: str
    rule_type: str  # attendance | academic | behavioral
    severity: str   # warning | danger | info
    student_id: uuid.UUID
    student_name: str
    class_id: uuid.UUID
    class_name: str
    message: str
    metric_value: float | int | None = None


class SearchItem(BaseModel):
    id: uuid.UUID
    type: str  # class | student | lesson | document | task
    title: str
    subtitle: str | None = None


class SearchResultsOut(BaseModel):
    query: str
    total: int
    results: list[SearchItem]


class BulletinGradeItem(BaseModel):
    assessment_id: uuid.UUID
    title: str
    kind: str
    date: str | None = None
    coefficient: float = 1.0
    score: float | None = None
    max_score: float = 20.0
    normalized_20: float | None = None


class StudentBulletinOut(BaseModel):
    school_name: str
    teacher_name: str
    academic_year: str
    class_id: uuid.UUID
    class_name: str
    term: str
    student_id: uuid.UUID
    student_name: str
    registration_number: str | None = None
    birth_date: str | None = None
    grades: list[BulletinGradeItem]
    total_coefficient: float
    weighted_sum: float
    general_average: float
    rank_in_class: int
    total_students: int
    class_highest_average: float
    class_lowest_average: float
    class_overall_average: float
    absences_count: int
    lateness_count: int
    honor_roll: str | None = None
    teacher_appreciation: str


class ImportRosterRow(BaseModel):
    first_name: str
    last_name: str
    gender: str | None = None
    birth_date: str | None = None
    registration_number: str | None = None


class ImportRosterRequest(BaseModel):
    csv_content: str | None = None
    rows: list[ImportRosterRow] | None = None


class ImportRosterResponse(BaseModel):
    total_processed: int
    total_created: int
    total_skipped: int
    errors: list[str]
