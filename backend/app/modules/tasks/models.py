import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class Task(SyncMixin, Base):
    __tablename__ = "tasks"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    priority: Mapped[str] = mapped_column(String(6), default="medium", nullable=False)
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    recurrence_rule: Mapped[str | None] = mapped_column(Text)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (CheckConstraint("priority in ('low','medium','high')", name="priority_valid"),)


class TaskReminder(SyncMixin, Base):
    __tablename__ = "task_reminders"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    task_id: Mapped[uuid.UUID] = fk("tasks.id")
    remind_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
