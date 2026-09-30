import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class SyncRecord(IdMixin, TimestampMixin, Base):
    """Idempotency ledger: one row per client mutation the server has already applied.
    Replaying the same `mutation_id` returns the stored result and never duplicates data."""
    __tablename__ = "sync_records"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    device_id: Mapped[str] = mapped_column(String(128), nullable=False)
    mutation_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(40), nullable=False)
    entity_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    operation: Mapped[str] = mapped_column(String(6), nullable=False)
    result_version: Mapped[int | None] = mapped_column(Integer)
    outcome: Mapped[str] = mapped_column(String(10), nullable=False)
    __table_args__ = (
        UniqueConstraint("teacher_id", "mutation_id", name="uq_sync_records_mutation"),
        CheckConstraint("operation in ('CREATE','UPDATE','DELETE')", name="operation_valid"),
        CheckConstraint("outcome in ('applied','conflict','rejected')", name="outcome_valid"),
        Index("ix_sync_records_teacher_entity", "teacher_id", "entity_type", "entity_id"),
    )
