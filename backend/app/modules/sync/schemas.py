import uuid
from typing import Any
from pydantic import BaseModel, Field


class ClientMutation(BaseModel):
    mutation_id: uuid.UUID
    entity_type: str
    entity_id: str
    operation: str = Field(pattern="^(CREATE|UPDATE|DELETE)$")
    base_version: int = Field(default=0)
    payload: dict[str, Any] | str


class SyncPushRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=128)
    mutations: list[ClientMutation] = []


class MutationOutcome(BaseModel):
    mutation_id: uuid.UUID
    entity_type: str
    entity_id: str
    outcome: str = Field(pattern="^(applied|conflict|rejected)$")
    version: int | None = None
    server_state: dict[str, Any] | None = None
    error: str | None = None


class SyncPushResponse(BaseModel):
    outcomes: list[MutationOutcome]


class SyncPullResponse(BaseModel):
    cursor: str
    changes: list[dict[str, Any]]
