import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class Template(SyncMixin, Base):
    __tablename__ = "templates"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    kind: Mapped[str] = mapped_column(String(20), nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    content: Mapped[dict] = mapped_column(JSONB, nullable=False)
    __table_args__ = (CheckConstraint("kind in ('lesson','exam','attendance','report','assignment')", name="kind_valid"),)


class Favorite(IdMixin, TimestampMixin, Base):
    __tablename__ = "favorites"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    entity_type: Mapped[str] = mapped_column(String(30), nullable=False)
    entity_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    __table_args__ = (UniqueConstraint("teacher_id", "entity_type", "entity_id", name="uq_favorites_target"),)
