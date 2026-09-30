import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.audit_model import AuditLog
from app.core.database import get_db
from app.core.exceptions import AppError, NotFound
from app.modules.assessments.models import Assessment, AssessmentResult
from app.modules.assessments.schemas import (
    AssessmentCreate,
    AssessmentDetailOut,
    AssessmentOut,
    ResultEntryOut,
    ResultsBulkSaveRequest,
)
from app.modules.classes.models import SchoolClass
from app.modules.students.models import ClassStudent, Student
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/assessments", tags=["assessments"])


@router.get("", response_model=list[AssessmentOut])
def list_assessments(
    class_id: uuid.UUID = Query(...),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    query = (
        select(Assessment)
        .where(
            Assessment.teacher_id == tid,
            Assessment.class_id == class_id,
            Assessment.deleted_at.is_(None),
        )
        .order_by(Assessment.assessed_on.desc(), Assessment.created_at.desc())
    )
    rows = db.scalars(query).all()

    return [
        AssessmentOut(
            id=a.id,
            class_id=a.class_id,
            title=a.title,
            kind=a.kind,
            assessed_on=a.assessed_on,
            max_score=float(a.max_score),
            coefficient=float(a.coefficient),
            version=a.version,
        )
        for a in rows
    ]


@router.post("", response_model=AssessmentOut)
def create_assessment(
    req: AssessmentCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    cls = db.scalar(
        select(SchoolClass).where(
            SchoolClass.id == req.class_id,
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
        )
    )
    if not cls:
        raise NotFound("Class not found.")

    assessment = Assessment(
        teacher_id=tid,
        class_id=cls.id,
        subject_id=cls.subject_id,
        academic_year_id=cls.academic_year_id,
        title=req.title.strip(),
        kind=req.kind,
        assessed_on=req.assessed_on,
        max_score=req.max_score,
        coefficient=req.coefficient,
    )
    db.add(assessment)
    db.flush()

    return AssessmentOut(
        id=assessment.id,
        class_id=assessment.class_id,
        title=assessment.title,
        kind=assessment.kind,
        assessed_on=assessment.assessed_on,
        max_score=float(assessment.max_score),
        coefficient=float(assessment.coefficient),
        version=assessment.version,
    )


@router.get("/{assessment_id}", response_model=AssessmentDetailOut)
def get_assessment_detail(
    assessment_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    assessment = db.scalar(
        select(Assessment).where(
            Assessment.id == assessment_id,
            Assessment.teacher_id == tid,
            Assessment.deleted_at.is_(None),
        )
    )
    if not assessment:
        raise NotFound("Assessment not found.")

    # All students in the class
    students = db.scalars(
        select(Student)
        .join(ClassStudent, ClassStudent.student_id == Student.id)
        .where(
            ClassStudent.class_id == assessment.class_id,
            ClassStudent.deleted_at.is_(None),
            Student.deleted_at.is_(None),
        )
        .order_by(Student.last_name, Student.first_name)
    ).all()

    # Results
    results = db.scalars(
        select(AssessmentResult).where(
            AssessmentResult.assessment_id == assessment.id,
            AssessmentResult.teacher_id == tid,
            AssessmentResult.deleted_at.is_(None),
        )
    ).all()
    result_map = {r.student_id: r for r in results}

    items = []
    for s in students:
        r = result_map.get(s.id)
        items.append(
            ResultEntryOut(
                id=r.id if r else uuid.uuid4(),
                assessment_id=assessment.id,
                student_id=s.id,
                student_name=f"{s.first_name} {s.last_name}",
                score=float(r.score) if (r and r.score is not None) else None,
                status=r.status if r else "pending",
                version=r.version if r else 0,
            )
        )

    return AssessmentDetailOut(
        id=assessment.id,
        class_id=assessment.class_id,
        title=assessment.title,
        kind=assessment.kind,
        assessed_on=assessment.assessed_on,
        max_score=float(assessment.max_score),
        coefficient=float(assessment.coefficient),
        version=assessment.version,
        results=items,
    )


@router.post("/{assessment_id}/results", response_model=list[ResultEntryOut])
def save_assessment_results(
    assessment_id: uuid.UUID,
    req: ResultsBulkSaveRequest,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    actor_uid = uuid.UUID(principal.user_id)

    assessment = db.scalar(
        select(Assessment).where(
            Assessment.id == assessment_id,
            Assessment.teacher_id == tid,
            Assessment.deleted_at.is_(None),
        )
    )
    if not assessment:
        raise NotFound("Assessment not found.")

    max_score = float(assessment.max_score)

    out_list = []
    for item in req.results:
        if item.score is not None and item.score > max_score:
            raise AppError(f"Score ({item.score}) cannot exceed max score ({max_score}).")

        res_row = db.scalar(
            select(AssessmentResult).where(
                AssessmentResult.assessment_id == assessment.id,
                AssessmentResult.student_id == item.student_id,
                AssessmentResult.teacher_id == tid,
            )
        )

        student = db.scalar(select(Student).where(Student.id == item.student_id))
        s_name = f"{student.first_name} {student.last_name}" if student else ""

        if res_row is None:
            res_row = AssessmentResult(
                teacher_id=tid,
                assessment_id=assessment.id,
                student_id=item.student_id,
                score=item.score,
                status=item.status,
            )
            db.add(res_row)
            db.flush()

            # Audit
            audit = AuditLog(
                teacher_id=tid,
                actor_user_id=actor_uid,
                action="create_grade",
                entity_type="assessment_result",
                entity_id=res_row.id,
                before=None,
                after={"score": item.score, "status": item.status},
            )
            db.add(audit)
        else:
            old_score = float(res_row.score) if res_row.score is not None else None
            if old_score != item.score or res_row.status != item.status or res_row.deleted_at is not None:
                before_state = {"score": old_score, "status": res_row.status}
                res_row.score = item.score
                res_row.status = item.status
                res_row.deleted_at = None
                res_row.version += 1
                db.flush()

                # Audit
                audit = AuditLog(
                    teacher_id=tid,
                    actor_user_id=actor_uid,
                    action="update_grade",
                    entity_type="assessment_result",
                    entity_id=res_row.id,
                    before=before_state,
                    after={"score": item.score, "status": item.status},
                )
                db.add(audit)

        out_list.append(
            ResultEntryOut(
                id=res_row.id,
                assessment_id=assessment.id,
                student_id=res_row.student_id,
                student_name=s_name,
                score=float(res_row.score) if res_row.score is not None else None,
                status=res_row.status,
                version=res_row.version,
            )
        )

    return out_list
