import uuid
from datetime import date, datetime, time

from sqlalchemy import (Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, Integer, Numeric, String,
                        Text, Time, UniqueConstraint)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.shared.models_base import Base, IdMixin, SyncMixin, TimestampMixin, fk



class DocumentFolder(SyncMixin, Base):
    __tablename__ = "document_folders"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")
    parent_id: Mapped[uuid.UUID | None] = fk("document_folders.id", nullable=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)


class Document(SyncMixin, Base):
    """Metadata only. Bytes live in S3-compatible storage under `storage_key` (spec §58)."""
    __tablename__ = "documents"
    teacher_id: Mapped[uuid.UUID] = fk("teachers.id")  # owner
    folder_id: Mapped[uuid.UUID | None] = fk("document_folders.id", nullable=True, ondelete="SET NULL")
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(120), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    storage_key: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    __table_args__ = (CheckConstraint("size_bytes >= 0", name="size_nonneg"),)
