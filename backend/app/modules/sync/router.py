import json
import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import NotFound
from app.modules.academic_years.models import AcademicYear
from app.modules.classes.models import SchoolClass, Subject
from app.modules.students.models import ClassStudent, Student
from app.modules.sync.models import SyncRecord
from app.modules.sync.schemas import (
    ClientMutation,
    MutationOutcome,
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
)
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("", response_model=SyncPushResponse)
def push_mutations(
    req: SyncPushRequest,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id or not principal.school_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    sid = uuid.UUID(principal.school_id)

    outcomes = []

    for mut in req.mutations:
        # 1. Idempotency check
        existing = db.scalar(
            select(SyncRecord).where(
                SyncRecord.teacher_id == tid,
                SyncRecord.mutation_id == mut.mutation_id,
            )
        )
        if existing:
            outcomes.append(
                MutationOutcome(
                    mutation_id=mut.mutation_id,
                    entity_type=mut.entity_type,
                    entity_id=mut.entity_id,
                    outcome=existing.outcome,
                    version=existing.result_version,
                )
            )
            continue

        try:
            payload = mut.payload if isinstance(mut.payload, dict) else json.loads(mut.payload)
        except Exception:
            payload = {}

        outcome = "applied"
        res_version = 1
        server_state: dict[str, Any] | None = None
        err_msg: str | None = None

        try:
            if mut.entity_type == "class":
                out_status, res_version, server_state, err_msg = _process_class_mutation(
                    db, tid, sid, mut, payload
                )
                outcome = out_status

            elif mut.entity_type == "student":
                out_status, res_version, server_state, err_msg = _process_student_mutation(
                    db, tid, sid, mut, payload
                )
                outcome = out_status

            else:
                outcome = "applied"
                res_version = 1

        except Exception as e:
            outcome = "rejected"
            err_msg = str(e)
            res_version = None

        # Record idempotency entry
        try:
            record_id = uuid.uuid4()
            try:
                e_id = uuid.UUID(mut.entity_id)
            except Exception:
                e_id = record_id

            rec = SyncRecord(
                teacher_id=tid,
                device_id=req.device_id,
                mutation_id=mut.mutation_id,
                entity_type=mut.entity_type,
                entity_id=e_id,
                operation=mut.operation,
                result_version=res_version,
                outcome=outcome,
            )
            db.add(rec)
            db.flush()
        except Exception:
            pass

        outcomes.append(
            MutationOutcome(
                mutation_id=mut.mutation_id,
                entity_type=mut.entity_type,
                entity_id=mut.entity_id,
                outcome=outcome,
                version=res_version,
                server_state=server_state,
                error=err_msg,
            )
        )

    return SyncPushResponse(outcomes=outcomes)


def _process_class_mutation(
    db: Session,
    tid: uuid.UUID,
    sid: uuid.UUID,
    mut: ClientMutation,
    payload: dict,
) -> tuple[str, int | None, dict | None, str | None]:
    now = datetime.now(timezone.utc)
    if mut.operation == "CREATE":
        subj_name = (payload.get("subject_name") or "المادة العامة").strip()
        subj = db.scalar(select(Subject).where(Subject.teacher_id == tid, Subject.name == subj_name))
        if not subj:
            subj = Subject(teacher_id=tid, name=subj_name)
            db.add(subj)
            db.flush()

        current_year = db.scalar(
            select(AcademicYear).where(AcademicYear.teacher_id == tid, AcademicYear.is_current.is_(True))
        )
        year_id = current_year.id if current_year else None
        if not year_id:
            ay = AcademicYear(school_id=sid, teacher_id=tid, label="2026-2027", starts_on=now.date(), ends_on=now.date(), is_current=True)
            db.add(ay)
            db.flush()
            year_id = ay.id

        cls = SchoolClass(
            teacher_id=tid,
            school_id=sid,
            academic_year_id=year_id,
            subject_id=subj.id,
            name=payload.get("name", "قسم جديد").strip(),
            level=payload.get("level"),
        )
        db.add(cls)
        db.flush()
        return "applied", cls.version, None, None

    # UPDATE / DELETE
    try:
        c_uuid = uuid.UUID(mut.entity_id)
    except Exception:
        return "rejected", None, None, "Invalid class UUID"

    cls = db.scalar(select(SchoolClass).where(SchoolClass.id == c_uuid, SchoolClass.teacher_id == tid))
    if not cls:
        return "rejected", None, None, "Class not found"

    if mut.base_version > 0 and cls.version != mut.base_version:
        return "conflict", cls.version, {"name": cls.name, "version": cls.version}, "Conflict: server has newer version"

    if mut.operation == "DELETE":
        cls.deleted_at = now
        cls.version += 1
        db.flush()
        return "applied", cls.version, None, None

    # Update
    if "name" in payload:
        cls.name = payload["name"].strip()
    if "level" in payload:
        cls.level = payload["level"]
    cls.version += 1
    db.flush()
    return "applied", cls.version, None, None


def _process_student_mutation(
    db: Session,
    tid: uuid.UUID,
    sid: uuid.UUID,
    mut: ClientMutation,
    payload: dict,
) -> tuple[str, int | None, dict | None, str | None]:
    now = datetime.now(timezone.utc)
    if mut.operation == "CREATE":
        student = Student(
            teacher_id=tid,
            school_id=sid,
            first_name=payload.get("first_name", "").strip(),
            last_name=payload.get("last_name", "").strip(),
            external_ref=payload.get("external_ref"),
        )
        db.add(student)
        db.flush()

        class_id_raw = payload.get("class_id")
        if class_id_raw:
            try:
                c_uuid = uuid.UUID(class_id_raw)
                link = ClassStudent(teacher_id=tid, class_id=c_uuid, student_id=student.id)
                db.add(link)
                db.flush()
            except Exception:
                pass

        return "applied", student.version, None, None

    # UPDATE / DELETE
    try:
        s_uuid = uuid.UUID(mut.entity_id)
    except Exception:
        return "rejected", None, None, "Invalid student UUID"

    student = db.scalar(select(Student).where(Student.id == s_uuid, Student.teacher_id == tid))
    if not student:
        return "rejected", None, None, "Student not found"

    if mut.base_version > 0 and student.version != mut.base_version:
        return "conflict", student.version, {"first_name": student.first_name, "last_name": student.last_name, "version": student.version}, "Conflict: server has newer version"

    if mut.operation == "DELETE":
        student.deleted_at = now
        student.version += 1
        db.flush()
        return "applied", student.version, None, None

    if "first_name" in payload:
        student.first_name = payload["first_name"].strip()
    if "last_name" in payload:
        student.last_name = payload["last_name"].strip()
    if "external_ref" in payload:
        student.external_ref = payload["external_ref"]

    student.version += 1
    db.flush()
    return "applied", student.version, None, None


@router.get("/changes", response_model=SyncPullResponse)
def get_changes(
    cursor: str | None = Query(None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    since = None
    if cursor:
        try:
            since = datetime.fromisoformat(cursor)
        except Exception:
            pass

    classes_q = select(SchoolClass).where(SchoolClass.teacher_id == tid)
    students_q = select(Student).where(Student.teacher_id == tid)

    if since:
        classes_q = classes_q.where(SchoolClass.updated_at >= since)
        students_q = students_q.where(Student.updated_at >= since)

    classes = db.scalars(classes_q).all()
    students = db.scalars(students_q).all()

    changes = []
    for c in classes:
        changes.append({
            "entity_type": "class",
            "id": str(c.id),
            "name": c.name,
            "level": c.level,
            "version": c.version,
            "deleted_at": c.deleted_at.isoformat() if c.deleted_at else None,
        })

    for s in students:
        changes.append({
            "entity_type": "student",
            "id": str(s.id),
            "first_name": s.first_name,
            "last_name": s.last_name,
            "external_ref": s.external_ref,
            "version": s.version,
            "deleted_at": s.deleted_at.isoformat() if s.deleted_at else None,
        })

    next_cursor = datetime.now(timezone.utc).isoformat()
    return SyncPullResponse(cursor=next_cursor, changes=changes)
