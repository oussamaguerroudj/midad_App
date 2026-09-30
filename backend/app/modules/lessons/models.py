import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class Lesson(SyncMixin, Base):
    """A planned lesson; the same row carries the teacher-journal fields (completion + covered content)."""
    __tablename__ = "lessons"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID | None] = fk("classes.id", nullable=True, ondelete="SET NULL")
    subject_id: Mapped[uuid.UUID] = fk("subjects.id", ondelete="RESTRICT")
    academic_year_id: Mapped[uuid.UUID] = fk("academic_years.id", ondelete="RESTRICT")
    curriculum_lesson_id: Mapped[uuid.UUID | None] = fk("curriculum_lessons.id", nullable=True, ondelete="SET NULL")
    topic: Mapped[str] = mapped_column(String(240), nullable=False)
    lesson_date: Mapped[date | None] = mapped_column(Date, index=True)
    duration_min: Mapped[int | None] = mapped_column(Integer)
    objectives: Mapped[str | None] = mapped_column(Text)
    content: Mapped[str | None] = mapped_column(Text)
    activities: Mapped[str | None] = mapped_column(Text)
    homework: Mapped[str | None] = mapped_column(Text)
    notes: Mapped[str | None] = mapped_column(Text)
    journal_covered: Mapped[str | None] = mapped_column(Text)
    completion: Mapped[str] = mapped_column(String(12), default="planned", nullable=False)
    __table_args__ = (CheckConstraint("completion in ('planned','in_progress','completed')", name="completion_valid"),)


class LessonResource(SyncMixin, Base):
    __tablename__ = "lesson_resources"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    lesson_id: Mapped[uuid.UUID] = fk("lessons.id")
    document_id: Mapped[uuid.UUID | None] = fk("documents.id", nullable=True, ondelete="SET NULL")
    label: Mapped[str] = mapped_column(String(200), nullable=False)
    url: Mapped[str | None] = mapped_column(Text)
