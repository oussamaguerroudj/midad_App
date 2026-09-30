import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class Subject(SyncMixin, Base):
    __tablename__ = "subjects"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    code: Mapped[str | None] = mapped_column(String(20))
    __table_args__ = (UniqueConstraint("teacher_id", "name", name="uq_subjects_teacher_name"),)


class SchoolClass(SyncMixin, Base):
    __tablename__ = "classes"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    school_id: Mapped[uuid.UUID] = fk("schools.id")
    academic_year_id: Mapped[uuid.UUID] = fk("academic_years.id", ondelete="RESTRICT")
    subject_id: Mapped[uuid.UUID] = fk("subjects.id", ondelete="RESTRICT")
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    level: Mapped[str | None] = mapped_column(String(60))
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (UniqueConstraint("teacher_id", "academic_year_id", "subject_id", "name",
                                       name="uq_classes_teacher_year_subject_name"),)


class TeacherClass(IdMixin, TimestampMixin, Base):
    """Membership/role link; enables co-teaching later without changing `classes`."""
    __tablename__ = "teacher_classes"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID] = fk("classes.id")
    role: Mapped[str] = mapped_column(String(20), default="owner", nullable=False)
    __table_args__ = (UniqueConstraint("teacher_id", "class_id", name="uq_teacher_classes_pair"),)
