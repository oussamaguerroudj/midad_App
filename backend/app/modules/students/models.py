import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class Student(SyncMixin, Base):
    __tablename__ = "students"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    school_id: Mapped[uuid.UUID] = fk("schools.id")
    first_name: Mapped[str] = mapped_column(String(120), nullable=False)
    last_name: Mapped[str] = mapped_column(String(120), nullable=False)
    external_ref: Mapped[str | None] = mapped_column(String(64))  # school-issued number, optional
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (Index("ix_students_teacher_name", "teacher_id", "last_name", "first_name"),)


class ClassStudent(SyncMixin, Base):
    __tablename__ = "class_students"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID] = fk("classes.id")
    student_id: Mapped[uuid.UUID] = fk("students.id")
    __table_args__ = (UniqueConstraint("class_id", "student_id", name="uq_class_students_pair"),)


class StudentNote(SyncMixin, Base):
    """Private teacher note. Factual/observable wording only (spec §17)."""
    __tablename__ = "student_notes"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    student_id: Mapped[uuid.UUID] = fk("students.id")
    class_id: Mapped[uuid.UUID | None] = fk("classes.id", nullable=True, ondelete="SET NULL")
    body: Mapped[str] = mapped_column(Text, nullable=False)


class StudentActivityLog(SyncMixin, Base):
    """Objective participation records (spec §31)."""
    __tablename__ = "student_activity_logs"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    student_id: Mapped[uuid.UUID] = fk("students.id")
    class_id: Mapped[uuid.UUID] = fk("classes.id")
    logged_on: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(30), nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
    __table_args__ = (CheckConstraint(
        "category in ('participated','completed_homework','late','positive_contribution','classroom_note')",
        name="category_valid"),)


class SeatingPlan(SyncMixin, Base):
    __tablename__ = "seating_plans"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID] = fk("classes.id")
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    layout: Mapped[str] = mapped_column(String(20), default="custom", nullable=False)
    __table_args__ = (CheckConstraint("layout in ('rows','groups','u_shape','custom')", name="layout_valid"),)


class SeatingPlanMember(SyncMixin, Base):
    __tablename__ = "seating_plan_members"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    plan_id: Mapped[uuid.UUID] = fk("seating_plans.id")
    student_id: Mapped[uuid.UUID | None] = fk("students.id", nullable=True, ondelete="SET NULL")
    seat_x: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False)
    seat_y: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False)


class StudentGroup(SyncMixin, Base):
    __tablename__ = "student_groups"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID] = fk("classes.id")
    name: Mapped[str] = mapped_column(String(120), nullable=False)


class GroupMember(SyncMixin, Base):
    __tablename__ = "group_members"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    group_id: Mapped[uuid.UUID] = fk("student_groups.id")
    student_id: Mapped[uuid.UUID] = fk("students.id")
    __table_args__ = (UniqueConstraint("group_id", "student_id", name="uq_group_members_pair"),)
