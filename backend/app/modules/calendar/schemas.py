import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class CalendarEventCreate(BaseModel):
    class_id: uuid.UUID | None = None
    title: str = Field(min_length=1, max_length=200)
    kind: str = Field(
        default="class",
        pattern="^(class|exam|assignment|meeting|correction|task|deadline|personal)$",
    )
    starts_at: datetime
    ends_at: datetime
    recurrence_rule: str | None = None
    reminder_minutes: int | None = None


class CalendarEventUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    kind: str | None = Field(
        default=None,
        pattern="^(class|exam|assignment|meeting|correction|task|deadline|personal)$",
    )
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    recurrence_rule: str | None = None
    reminder_minutes: int | None = None
    base_version: int = Field(description="Client version for optimistic locking")


class CalendarEventOut(BaseModel):
    id: uuid.UUID
    class_id: uuid.UUID | None = None
    title: str
    kind: str
    starts_at: datetime
    ends_at: datetime
    recurrence_rule: str | None = None
    reminder_minutes: int | None = None
    version: int
    created_at: datetime
    updated_at: datetime
