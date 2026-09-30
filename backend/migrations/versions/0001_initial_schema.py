"""Initial schema (all core tables, constraints and indexes).

Revision ID: 0001
Revises:
"""
from alembic import op

from app.shared.models_base import Base
import app.modules.registry  # noqa: F401

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Baseline only: creates the schema exactly as declared in the models at Phase 0.
    # EVERY later migration must be explicit (op.add_column, ...) so history stays reproducible.
    Base.metadata.create_all(bind=op.get_bind())


def downgrade() -> None:
    Base.metadata.drop_all(bind=op.get_bind())
