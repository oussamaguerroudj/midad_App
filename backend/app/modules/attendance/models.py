import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class AttendanceSession(SyncMixin, Base):
    __tablename__ = "attendance_sessions"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID] = fk("classes.id")
    academic_year_id: Mapped[uuid.UUID] = fk("academic_years.id", ondelete="RESTRICT")
    lesson_id: Mapped[uuid.UUID | None] = fk("lessons.id", nullable=True, ondelete="SET NULL")
    session_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    slot: Mapped[str] = mapped_column(String(20), default="", nullable=False)  # e.g. "08:00"; distinguishes 2 sessions/day
    __table_args__ = (UniqueConstraint("class_id", "session_date", "slot", name="uq_attendance_sessions_slot"),)


class AttendanceRecord(SyncMixin, Base):
    __tablename__ = "attendance_records"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    session_id: Mapped[uuid.UUID] = fk("attendance_sessions.id")
    student_id: Mapped[uuid.UUID] = fk("students.id")
    status: Mapped[str] = mapped_column(String(10), nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
    __table_args__ = (
        UniqueConstraint("session_id", "student_id", name="uq_attendance_records_pair"),
        CheckConstraint("status in ('present','absent','late','excused')", name="status_valid"),
    )
