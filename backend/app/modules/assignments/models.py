import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class Assignment(SyncMixin, Base):
    __tablename__ = "assignments"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID] = fk("classes.id")
    subject_id: Mapped[uuid.UUID] = fk("subjects.id", ondelete="RESTRICT")
    academic_year_id: Mapped[uuid.UUID] = fk("academic_years.id", ondelete="RESTRICT")
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    due_on: Mapped[date | None] = mapped_column(Date, index=True)


class AssignmentRecord(SyncMixin, Base):
    __tablename__ = "assignment_records"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    assignment_id: Mapped[uuid.UUID] = fk("assignments.id")
    student_id: Mapped[uuid.UUID] = fk("students.id")
    status: Mapped[str] = mapped_column(String(12), default="assigned", nullable=False)
    __table_args__ = (
        UniqueConstraint("assignment_id", "student_id", name="uq_assignment_records_pair"),
        CheckConstraint("status in ('assigned','completed','missing','excused')", name="status_valid"),
    )
