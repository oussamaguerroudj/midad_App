import uuid
from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.core.audit_model import AuditLog
from app.core.database import get_db
from app.core.exceptions import NotFound
from app.modules.assessments.models import Assessment, AssessmentResult
from app.modules.attendance.models import AttendanceRecord, AttendanceSession
from app.modules.classes.models import SchoolClass
from app.modules.documents.models import Document
from app.modules.lessons.models import Lesson
from app.modules.reports.schemas import (
    AuditLogOut,
    FollowUpAlertOut,
    SearchItem,
    SearchResultsOut,
)
from app.modules.students.models import ClassStudent, Student
from app.modules.tasks.models import Task
from app.shared.deps import Principal, current_principal

router = APIRouter(tags=["reports"])


# --- Activity History ---

@router.get("/activity-history", response_model=list[AuditLogOut])
def get_activity_history(
    entity_type: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    stmt = select(AuditLog).where(AuditLog.teacher_id == tid)
    if entity_type:
        stmt = stmt.where(AuditLog.entity_type == entity_type)

    stmt = stmt.order_by(AuditLog.occurred_at.desc()).limit(limit).offset(offset)
    return db.execute(stmt).scalars().all()


# --- Follow-Up Rules & Alerts ---

@router.get("/follow-up-alerts", response_model=list[FollowUpAlertOut])
def get_follow_up_alerts(
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    """Evaluates automatic follow-up rules across active classes:
    - Rule 1 (Attendance): 3 or more absences in attendance records.
    - Rule 2 (Academic): Assessment average under 10/20.
    """
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    alerts: list[FollowUpAlertOut] = []

    # 1. Attendance Rule: count unexcused / absent status per student per class
    att_stmt = (
        select(
            Student.id,
            Student.first_name,
            Student.last_name,
            SchoolClass.id,
            SchoolClass.name,
            func.count(AttendanceRecord.id).label("absent_count"),
        )
        .join(AttendanceRecord, AttendanceRecord.student_id == Student.id)
        .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
        .join(SchoolClass, SchoolClass.id == AttendanceSession.class_id)
        .where(
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
            SchoolClass.deleted_at.is_(None),
            AttendanceRecord.deleted_at.is_(None),
            AttendanceRecord.status.in_(["absent", "late"]),
        )
        .group_by(Student.id, Student.first_name, Student.last_name, SchoolClass.id, SchoolClass.name)
        .having(func.count(AttendanceRecord.id) >= 3)
    )
    att_results = db.execute(att_stmt).all()
    for row in att_results:
        s_id, s_first, s_last, c_id, c_name, count = row
        alerts.append(
            FollowUpAlertOut(
                id=f"att-{s_id}-{c_id}",
                rule_type="attendance",
                severity="danger" if count >= 5 else "warning",
                student_id=s_id,
                student_name=f"{s_first} {s_last}",
                class_id=c_id,
                class_name=c_name,
                message=f"تنبيه غياب: {count} تسجيلات غياب/تأخر مسجلة لهذا التلميذ في {c_name}.",
                metric_value=count,
            )
        )

    # 2. Academic Rule: average score < 10 for students with at least 1 graded assessment
    grade_stmt = (
        select(
            Student.id,
            Student.first_name,
            Student.last_name,
            SchoolClass.id,
            SchoolClass.name,
            func.avg(AssessmentResult.score).label("avg_score"),
        )
        .join(AssessmentResult, AssessmentResult.student_id == Student.id)
        .join(Assessment, Assessment.id == AssessmentResult.assessment_id)
        .join(SchoolClass, SchoolClass.id == Assessment.class_id)
        .where(
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
            AssessmentResult.deleted_at.is_(None),
            AssessmentResult.score.is_not(None),
        )
        .group_by(Student.id, Student.first_name, Student.last_name, SchoolClass.id, SchoolClass.name)
        .having(func.avg(AssessmentResult.score) < 10.0)
    )
    grade_results = db.execute(grade_stmt).all()
    for row in grade_results:
        s_id, s_first, s_last, c_id, c_name, avg_sc = row
        val = round(float(avg_sc), 2)
        alerts.append(
            FollowUpAlertOut(
                id=f"acad-{s_id}-{c_id}",
                rule_type="academic",
                severity="warning",
                student_id=s_id,
                student_name=f"{s_first} {s_last}",
                class_id=c_id,
                class_name=c_name,
                message=f"متابعة تحصيلية: معدل التقييمات {val}/20 يقل عن عتبة التمكّن في {c_name}.",
                metric_value=val,
            )
        )

    return alerts


# --- Global Search ---

@router.get("/search", response_model=SearchResultsOut)
def global_search(
    q: str = Query(..., min_length=1),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    term = f"%{q.strip()}%"

    results: list[SearchItem] = []

    # Classes
    classes = db.execute(
        select(SchoolClass).where(
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
            SchoolClass.name.ilike(term),
        ).limit(5)
    ).scalars().all()
    for c in classes:
        results.append(SearchItem(id=c.id, type="class", title=c.name, subtitle=c.level or "قسم"))

    # Students
    students = db.execute(
        select(Student).where(
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
            or_(Student.first_name.ilike(term), Student.last_name.ilike(term)),
        ).limit(10)
    ).scalars().all()
    for s in students:
        results.append(SearchItem(id=s.id, type="student", title=f"{s.first_name} {s.last_name}", subtitle=s.external_ref or "تلميذ"))

    # Lessons
    lessons = db.execute(
        select(Lesson).where(
            Lesson.teacher_id == tid,
            Lesson.deleted_at.is_(None),
            Lesson.topic.ilike(term),
        ).limit(5)
    ).scalars().all()
    for l in lessons:
        results.append(SearchItem(id=l.id, type="lesson", title=l.topic, subtitle="مذكرة درس"))

    # Documents
    docs = db.execute(
        select(Document).where(
            Document.teacher_id == tid,
            Document.deleted_at.is_(None),
            Document.file_name.ilike(term),
        ).limit(5)
    ).scalars().all()
    for d in docs:
        results.append(SearchItem(id=d.id, type="document", title=d.file_name, subtitle=f"{round(d.size_bytes/1024, 1)} KB"))

    # Tasks
    tasks = db.execute(
        select(Task).where(
            Task.teacher_id == tid,
            Task.deleted_at.is_(None),
            Task.title.ilike(term),
        ).limit(5)
    ).scalars().all()
    for t in tasks:
        results.append(SearchItem(id=t.id, type="task", title=t.title, subtitle="مهمة"))

    return SearchResultsOut(
        query=q,
        total=len(results),
        results=results,
    )
