import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.audit_model import AuditLog
from app.core.database import get_db
from app.core.exceptions import Conflict, NotFound
from app.modules.assignments.models import Assignment, AssignmentRecord
from app.modules.assignments.schemas import (
    AssignmentCreate,
    AssignmentOut,
    AssignmentRecordItem,
    AssignmentRecordOut,
    AssignmentUpdate,
    BulkAssignmentRecords,
)
from app.modules.students.models import Student
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/assignments", tags=["assignments"])


@router.post("", response_model=AssignmentOut, status_code=status.HTTP_201_CREATED)
def create_assignment(
    payload: AssignmentCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> AssignmentOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    assignment = Assignment(
        teacher_id=tid,
        class_id=payload.class_id,
        subject_id=payload.subject_id,
        academic_year_id=payload.academic_year_id,
        title=payload.title,
        description=payload.description,
        due_on=payload.due_on,
        version=1,
    )
    db.add(assignment)
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="assignment_create",
            entity_type="assignment",
            entity_id=assignment.id,
            after={"title": assignment.title, "class_id": str(assignment.class_id)},
        )
    )
    db.commit()
    return assignment


@router.get("", response_model=list[AssignmentOut])
def list_assignments(
    class_id: uuid.UUID | None = Query(default=None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> list[AssignmentOut]:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    q = select(Assignment).where(
        Assignment.teacher_id == tid,
        Assignment.deleted_at.is_(None),
    )
    if class_id:
        q = q.where(Assignment.class_id == class_id)
    q = q.order_by(Assignment.due_on.desc(), Assignment.created_at.desc())
    return list(db.scalars(q).all())


@router.get("/{assignment_id}", response_model=AssignmentOut)
def get_assignment(
    assignment_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> AssignmentOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    assignment = db.scalar(
        select(Assignment).where(
            Assignment.id == assignment_id,
            Assignment.teacher_id == tid,
            Assignment.deleted_at.is_(None),
        )
    )
    if not assignment:
        raise NotFound("Assignment not found")
    return assignment


@router.patch("/{assignment_id}", response_model=AssignmentOut)
def update_assignment(
    assignment_id: uuid.UUID,
    payload: AssignmentUpdate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> AssignmentOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    assignment = db.scalar(
        select(Assignment).where(
            Assignment.id == assignment_id,
            Assignment.teacher_id == tid,
            Assignment.deleted_at.is_(None),
        )
    )
    if not assignment:
        raise NotFound("Assignment not found")

    if assignment.version != payload.base_version:
        raise Conflict(f"Version conflict: current {assignment.version} != client {payload.base_version}")

    before = {"title": assignment.title, "due_on": str(assignment.due_on)}

    if payload.title is not None:
        assignment.title = payload.title
    if payload.description is not None:
        assignment.description = payload.description
    if payload.due_on is not None:
        assignment.due_on = payload.due_on

    assignment.version += 1
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="assignment_update",
            entity_type="assignment",
            entity_id=assignment.id,
            before=before,
            after={"title": assignment.title, "due_on": str(assignment.due_on)},
        )
    )
    db.commit()
    return assignment


@router.post("/{assignment_id}/records", response_model=list[AssignmentRecordOut])
def save_assignment_records(
    assignment_id: uuid.UUID,
    payload: BulkAssignmentRecords,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> list[AssignmentRecordOut]:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    assignment = db.scalar(
        select(Assignment).where(
            Assignment.id == assignment_id,
            Assignment.teacher_id == tid,
            Assignment.deleted_at.is_(None),
        )
    )
    if not assignment:
        raise NotFound("Assignment not found")

    existing = list(
        db.scalars(
            select(AssignmentRecord).where(
                AssignmentRecord.assignment_id == assignment_id,
                AssignmentRecord.teacher_id == tid,
                AssignmentRecord.deleted_at.is_(None),
            )
        ).all()
    )
    existing_map = {r.student_id: r for r in existing}

    saved: list[AssignmentRecord] = []
    for item in payload.records:
        rec = existing_map.get(item.student_id)
        if rec:
            rec.status = item.status
            rec.version += 1
        else:
            rec = AssignmentRecord(
                teacher_id=tid,
                assignment_id=assignment_id,
                student_id=item.student_id,
                status=item.status,
                version=1,
            )
            db.add(rec)
        db.flush()
        saved.append(rec)

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="save_assignment_records",
            entity_type="assignment_record",
            entity_id=assignment_id,
            after={"count": len(saved)},
        )
    )
    db.commit()

    return [
        AssignmentRecordOut(
            id=r.id,
            assignment_id=r.assignment_id,
            student_id=r.student_id,
            status=r.status,
            version=r.version,
            updated_at=r.updated_at,
        )
        for r in saved
    ]


@router.get("/{assignment_id}/records", response_model=list[AssignmentRecordOut])
def get_assignment_records(
    assignment_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> list[AssignmentRecordOut]:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    assignment = db.scalar(
        select(Assignment).where(
            Assignment.id == assignment_id,
            Assignment.teacher_id == tid,
            Assignment.deleted_at.is_(None),
        )
    )
    if not assignment:
        raise NotFound("Assignment not found")

    q = (
        select(AssignmentRecord, Student)
        .join(Student, Student.id == AssignmentRecord.student_id)
        .where(
            AssignmentRecord.assignment_id == assignment_id,
            AssignmentRecord.teacher_id == tid,
            AssignmentRecord.deleted_at.is_(None),
        )
    )
    rows = db.execute(q).all()

    return [
        AssignmentRecordOut(
            id=rec.id,
            assignment_id=rec.assignment_id,
            student_id=rec.student_id,
            student_name=f"{stu.first_name} {stu.last_name}",
            status=rec.status,
            version=rec.version,
            updated_at=rec.updated_at,
        )
        for rec, stu in rows
    ]


@router.delete("/{assignment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_assignment(
    assignment_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> None:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    assignment = db.scalar(
        select(Assignment).where(
            Assignment.id == assignment_id,
            Assignment.teacher_id == tid,
            Assignment.deleted_at.is_(None),
        )
    )
    if not assignment:
        raise NotFound("Assignment not found")

    assignment.deleted_at = datetime.now(timezone.utc)
    assignment.version += 1
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="assignment_delete",
            entity_type="assignment",
            entity_id=assignment.id,
        )
    )
    db.commit()
