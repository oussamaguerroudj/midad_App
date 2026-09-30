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


# --- Phase 3: Seating Plans ---
class SeatingPlanMemberCreate(BaseModel):
    student_id: uuid.UUID | None = None
    seat_x: float
    seat_y: float


class SeatingPlanMemberOut(BaseModel):
    id: uuid.UUID
    plan_id: uuid.UUID
    student_id: uuid.UUID | None = None
    student_name: str | None = None
    seat_x: float
    seat_y: float


class SeatingPlanCreate(BaseModel):
    class_id: uuid.UUID
    name: str = Field(..., min_length=1, max_length=120)
    layout: str = Field(default="custom", pattern="^(rows|groups|u_shape|custom)$")
    members: list[SeatingPlanMemberCreate] = []


class SeatingPlanOut(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    name: str
    layout: str
    members: list[SeatingPlanMemberOut] = []
    version: int
    created_at: datetime
    updated_at: datetime


# --- Phase 3: Student Groups ---
class StudentGroupCreate(BaseModel):
    class_id: uuid.UUID
    name: str = Field(..., min_length=1, max_length=120)
    student_ids: list[uuid.UUID] = []


class StudentGroupMemberOut(BaseModel):
    id: uuid.UUID
    student_id: uuid.UUID
    student_name: str


class StudentGroupOut(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    name: str
    members: list[StudentGroupMemberOut] = []
    version: int
    created_at: datetime


# --- Phase 3: Student Activity / Participation Log ---
class StudentActivityLogCreate(BaseModel):
    student_id: uuid.UUID
    class_id: uuid.UUID
    logged_on: datetime | None = None
    category: str = Field(..., pattern="^(participated|completed_homework|late|positive_contribution|classroom_note)$")
    note: str | None = None


class StudentActivityLogOut(BaseModel):
    id: uuid.UUID
    student_id: uuid.UUID
    student_name: str
    class_id: uuid.UUID
    logged_on: datetime
    category: str
    note: str | None = None
    created_at: datetime
