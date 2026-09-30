import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class Teacher(SyncMixin, Base):
    __tablename__ = "teachers"
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
                                               unique=True, nullable=False)
    school_id: Mapped[uuid.UUID] = fk("schools.id", ondelete="RESTRICT")
    full_name: Mapped[str] = mapped_column(String(200), nullable=False)
    photo_key: Mapped[str | None] = mapped_column(Text)
    subjects: Mapped[list | None] = mapped_column(JSONB)
    settings: Mapped[dict | None] = mapped_column(JSONB)  # follow-up thresholds, dashboard layout
