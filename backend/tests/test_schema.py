"""Guards the spec: required tables exist, and no AI tables were created (spec §3)."""
from app.shared.models_base import Base
import app.modules.registry  # noqa: F401

REQUIRED = """users teachers schools academic_years subjects classes teacher_classes students class_students
attendance_sessions attendance_records assessments assessment_questions assessment_results lessons lesson_resources
curriculum_units curriculum_lessons curriculum_progress assignments assignment_records student_notes
student_activity_logs seating_plans seating_plan_members student_groups group_members documents document_folders
calendar_events tasks task_reminders notifications templates favorites audit_logs sync_records backup_records""".split()


def test_all_spec_tables_exist():
    assert set(REQUIRED) <= set(Base.metadata.tables)


def test_no_ai_tables():
    assert not [t for t in Base.metadata.tables if t.startswith("ai_")]


def test_every_teacher_owned_table_has_teacher_id():
    exempt = {"users", "refresh_tokens", "schools", "teachers"}
    missing = [n for n, t in Base.metadata.tables.items() if n not in exempt and "teacher_id" not in t.c]
    assert missing == [], missing
