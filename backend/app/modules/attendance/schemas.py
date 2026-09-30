import uuid
from datetime import date
from pydantic import BaseModel, Field


class AttendanceSessionCreate(BaseModel):
    class_id: uuid.UUID
    session_date: date
    slot: str = Field(default="", max_length=20)
    academic_year_id: uuid.UUID | None = None


class AttendanceSessionOut(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID
    session_date: date
    slot: str
    academic_year_id: uuid.UUID
    version: int


class AttendanceRecordIn(BaseModel):
    student_id: uuid.UUID
    status: str = Field(pattern="^(present|absent|late|excused)$")
    note: str | None = None


class AttendanceRecordOut(BaseModel):
    id: uuid.UUID
    session_id: uuid.UUID
    student_id: uuid.UUID
    student_name: str
    status: str
    note: str | None = None
    version: int


class AttendanceSessionDetailOut(AttendanceSessionOut):
    records: list[AttendanceRecordOut] = []


class AttendanceBulkSaveRequest(BaseModel):
    records: list[AttendanceRecordIn]
