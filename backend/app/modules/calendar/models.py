import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class CalendarEvent(SyncMixin, Base):
    __tablename__ = "calendar_events"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID | None] = fk("classes.id", nullable=True, ondelete="SET NULL")
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    kind: Mapped[str] = mapped_column(String(20), nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    recurrence_rule: Mapped[str | None] = mapped_column(Text)  # RFC 5545 RRULE
    reminder_minutes: Mapped[int | None] = mapped_column(Integer)
    __table_args__ = (
        CheckConstraint("ends_at >= starts_at", name="range_valid"),
        CheckConstraint("kind in ('class','exam','assignment','meeting','correction','task','deadline','personal')",
                        name="kind_valid"),
    )
