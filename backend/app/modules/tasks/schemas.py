import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    priority: str = Field(default="medium", pattern="^(low|medium|high)$")
    due_at: datetime | None = None
    recurrence_rule: str | None = None


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    priority: str | None = Field(default=None, pattern="^(low|medium|high)$")
    due_at: datetime | None = None
    completed: bool | None = None
    base_version: int = Field(description="Client version for optimistic locking")


class TaskOut(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None = None
    priority: str
    due_at: datetime | None = None
    recurrence_rule: str | None = None
    completed_at: datetime | None = None
    version: int
    created_at: datetime
    updated_at: datetime
