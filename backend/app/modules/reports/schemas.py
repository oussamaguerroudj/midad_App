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
