import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class Assessment(SyncMixin, Base):
    __tablename__ = "assessments"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    class_id: Mapped[uuid.UUID] = fk("classes.id")
    subject_id: Mapped[uuid.UUID] = fk("subjects.id", ondelete="RESTRICT")
    academic_year_id: Mapped[uuid.UUID] = fk("academic_years.id", ondelete="RESTRICT")
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    kind: Mapped[str] = mapped_column(String(20), nullable=False)
    assessed_on: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    max_score: Mapped[float] = mapped_column(Numeric(6, 2), default=20, nullable=False)
    coefficient: Mapped[float] = mapped_column(Numeric(4, 2), default=1, nullable=False)
    __table_args__ = (
        CheckConstraint("max_score > 0", name="max_positive"),
        CheckConstraint("coefficient > 0", name="coef_positive"),
        CheckConstraint("kind in ('homework','assignment','quiz','test','exam','project','participation','custom')",
                        name="kind_valid"),
    )


class AssessmentQuestion(SyncMixin, Base):
    __tablename__ = "assessment_questions"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    assessment_id: Mapped[uuid.UUID] = fk("assessments.id")
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    kind: Mapped[str] = mapped_column(String(20), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    points: Mapped[float] = mapped_column(Numeric(6, 2), nullable=False)
    instructions: Mapped[str | None] = mapped_column(Text)
    attachment_key: Mapped[str | None] = mapped_column(Text)
    __table_args__ = (
        UniqueConstraint("assessment_id", "position", name="uq_assessment_questions_pos"),
        CheckConstraint("points >= 0", name="points_nonneg"),
        CheckConstraint("kind in ('question','multiple_choice','true_false','exercise','short_answer','long_answer')",
                        name="kind_valid"),
    )


class AssessmentResult(SyncMixin, Base):
    """Grade for one student. Upper bound (score <= assessment.max_score) is enforced in the
    service layer AND by a DB trigger added in Phase 1 (cross-table checks cannot be CHECK constraints).
    Every change is recorded in audit_logs with before/after (spec §85)."""
    __tablename__ = "assessment_results"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    assessment_id: Mapped[uuid.UUID] = fk("assessments.id")
    student_id: Mapped[uuid.UUID] = fk("students.id")
    score: Mapped[float | None] = mapped_column(Numeric(6, 2))
    status: Mapped[str] = mapped_column(String(12), default="graded", nullable=False)
    __table_args__ = (
        UniqueConstraint("assessment_id", "student_id", name="uq_assessment_results_pair"),
        CheckConstraint("score is null or score >= 0", name="score_nonneg"),
        CheckConstraint("status in ('graded','absent','excused','pending')", name="status_valid"),
    )
