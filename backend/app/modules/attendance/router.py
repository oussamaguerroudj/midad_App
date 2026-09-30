import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.audit_model import AuditLog
from app.core.database import get_db
from app.core.exceptions import AppError, NotFound
from app.modules.academic_years.models import AcademicYear
from app.modules.attendance.models import AttendanceRecord, AttendanceSession
from app.modules.attendance.schemas import (
    AttendanceBulkSaveRequest,
    AttendanceRecordOut,
    AttendanceSessionCreate,
    AttendanceSessionDetailOut,
    AttendanceSessionOut,
)
from app.modules.classes.models import SchoolClass
from app.modules.students.models import ClassStudent, Student
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/attendance", tags=["attendance"])


@router.post("/sessions", response_model=AttendanceSessionOut)
def get_or_create_session(
    req: AttendanceSessionCreate,
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

    # Check existing session for class_id, date, slot
    existing = db.scalar(
        select(AttendanceSession).where(
            AttendanceSession.class_id == cls.id,
            AttendanceSession.session_date == req.session_date,
            AttendanceSession.slot == req.slot.strip(),
            AttendanceSession.deleted_at.is_(None),
        )
    )
    if existing:
        return AttendanceSessionOut(
            id=existing.id,
            class_id=existing.class_id,
            session_date=existing.session_date,
            slot=existing.slot,
            academic_year_id=existing.academic_year_id,
            version=existing.version,
        )

    year_id = req.academic_year_id or cls.academic_year_id
    session = AttendanceSession(
        teacher_id=tid,
        class_id=cls.id,
        academic_year_id=year_id,
        session_date=req.session_date,
        slot=req.slot.strip(),
    )
    db.add(session)
    db.flush()

    return AttendanceSessionOut(
        id=session.id,
        class_id=session.class_id,
        session_date=session.session_date,
        slot=session.slot,
        academic_year_id=session.academic_year_id,
        version=session.version,
    )


@router.get("/sessions", response_model=list[AttendanceSessionOut])
def list_sessions(
    class_id: uuid.UUID = Query(...),
    from_date: date | None = Query(None),
    to_date: date | None = Query(None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    query = select(AttendanceSession).where(
        AttendanceSession.teacher_id == tid,
        AttendanceSession.class_id == class_id,
        AttendanceSession.deleted_at.is_(None),
    )

    if from_date:
        query = query.where(AttendanceSession.session_date >= from_date)
    if to_date:
        query = query.where(AttendanceSession.session_date <= to_date)

    query = query.order_by(AttendanceSession.session_date.desc(), AttendanceSession.slot)
    rows = db.scalars(query).all()

    return [
        AttendanceSessionOut(
            id=s.id,
            class_id=s.class_id,
            session_date=s.session_date,
            slot=s.slot,
            academic_year_id=s.academic_year_id,
            version=s.version,
        )
        for s in rows
    ]


@router.get("/sessions/{session_id}", response_model=AttendanceSessionDetailOut)
def get_session_detail(
    session_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    sess = db.scalar(
        select(AttendanceSession).where(
            AttendanceSession.id == session_id,
            AttendanceSession.teacher_id == tid,
            AttendanceSession.deleted_at.is_(None),
        )
    )
    if not sess:
        raise NotFound("Attendance session not found.")

    # Fetch all students in the class
    students = db.scalars(
        select(Student)
        .join(ClassStudent, ClassStudent.student_id == Student.id)
        .where(
            ClassStudent.class_id == sess.class_id,
            ClassStudent.deleted_at.is_(None),
            Student.deleted_at.is_(None),
        )
        .order_by(Student.last_name, Student.first_name)
    ).all()

    # Fetch existing records
    records = db.scalars(
        select(AttendanceRecord).where(
            AttendanceRecord.session_id == sess.id,
            AttendanceRecord.teacher_id == tid,
            AttendanceRecord.deleted_at.is_(None),
        )
    ).all()
    record_map = {r.student_id: r for r in records}

    items = []
    for s in students:
        rec = record_map.get(s.id)
        items.append(
            AttendanceRecordOut(
                id=rec.id if rec else uuid.uuid4(),
                session_id=sess.id,
                student_id=s.id,
                student_name=f"{s.first_name} {s.last_name}",
                status=rec.status if rec else "present",
                note=rec.note if rec else None,
                version=rec.version if rec else 0,
            )
        )

    return AttendanceSessionDetailOut(
        id=sess.id,
        class_id=sess.class_id,
        session_date=sess.session_date,
        slot=sess.slot,
        academic_year_id=sess.academic_year_id,
        version=sess.version,
        records=items,
    )


@router.post("/sessions/{session_id}/records", response_model=list[AttendanceRecordOut])
def save_attendance_records(
    session_id: uuid.UUID,
    req: AttendanceBulkSaveRequest,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    actor_uid = uuid.UUID(principal.user_id)

    sess = db.scalar(
        select(AttendanceSession).where(
            AttendanceSession.id == session_id,
            AttendanceSession.teacher_id == tid,
            AttendanceSession.deleted_at.is_(None),
        )
    )
    if not sess:
        raise NotFound("Attendance session not found.")

    res_list = []
    for item in req.records:
        rec = db.scalar(
            select(AttendanceRecord).where(
                AttendanceRecord.session_id == sess.id,
                AttendanceRecord.student_id == item.student_id,
                AttendanceRecord.teacher_id == tid,
            )
        )

        student = db.scalar(select(Student).where(Student.id == item.student_id))
        s_name = f"{student.first_name} {student.last_name}" if student else ""

        if rec is None:
            # Create
            rec = AttendanceRecord(
                teacher_id=tid,
                session_id=sess.id,
                student_id=item.student_id,
                status=item.status,
                note=item.note,
            )
            db.add(rec)
            db.flush()

            # Audit log
            audit = AuditLog(
                teacher_id=tid,
                actor_user_id=actor_uid,
                action="create_attendance",
                entity_type="attendance_record",
                entity_id=rec.id,
                before=None,
                after={"status": rec.status, "note": rec.note},
            )
            db.add(audit)
        else:
            # Update if changed
            if rec.status != item.status or rec.note != item.note or rec.deleted_at is not None:
                before_state = {"status": rec.status, "note": rec.note}
                rec.status = item.status
                rec.note = item.note
                rec.deleted_at = None
                rec.version += 1
                db.flush()

                # Audit log
                audit = AuditLog(
                    teacher_id=tid,
                    actor_user_id=actor_uid,
                    action="update_attendance",
                    entity_type="attendance_record",
                    entity_id=rec.id,
                    before=before_state,
                    after={"status": rec.status, "note": rec.note},
                )
                db.add(audit)

        res_list.append(
            AttendanceRecordOut(
                id=rec.id,
                session_id=rec.session_id,
                student_id=rec.student_id,
                student_name=s_name,
                status=rec.status,
                note=rec.note,
                version=rec.version,
            )
        )

    return res_list
