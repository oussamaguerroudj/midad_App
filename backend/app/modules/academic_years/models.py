import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class AcademicYear(SyncMixin, Base):
    __tablename__ = "academic_years"
    school_id: Mapped[uuid.UUID] = fk("schools.id")
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    label: Mapped[str] = mapped_column(String(20), nullable=False)  # e.g. 2026-2027
    starts_on: Mapped[date] = mapped_column(Date, nullable=False)
    ends_on: Mapped[date] = mapped_column(Date, nullable=False)
    is_current: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    __table_args__ = (
        UniqueConstraint("teacher_id", "label", name="uq_academic_years_teacher_label"),
        CheckConstraint("ends_on > starts_on", name="range_valid"),
        # at most one current year per teacher
        Index("uq_academic_years_one_current", "teacher_id", unique=True, postgresql_where="is_current"),
    )
