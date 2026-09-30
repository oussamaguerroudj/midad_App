import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class CurriculumUnit(SyncMixin, Base):
    __tablename__ = "curriculum_units"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    subject_id: Mapped[uuid.UUID] = fk("subjects.id")
    level: Mapped[str] = mapped_column(String(60), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)


class CurriculumLesson(SyncMixin, Base):
    __tablename__ = "curriculum_lessons"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    unit_id: Mapped[uuid.UUID] = fk("curriculum_units.id")
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)


class CurriculumProgress(SyncMixin, Base):
    """Status per (class, curriculum lesson): progress is per class and per academic year."""
    __tablename__ = "curriculum_progress"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID] = fk("classes.id")
    curriculum_lesson_id: Mapped[uuid.UUID] = fk("curriculum_lessons.id")
    academic_year_id: Mapped[uuid.UUID] = fk("academic_years.id", ondelete="RESTRICT")
    status: Mapped[str] = mapped_column(String(12), default="not_started", nullable=False)
    __table_args__ = (
        UniqueConstraint("class_id", "curriculum_lesson_id", name="uq_curriculum_progress_pair"),
        CheckConstraint("status in ('not_started','in_progress','completed')", name="status_valid"),
    )
