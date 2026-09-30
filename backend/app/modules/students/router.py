import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import AppError, Conflict, NotFound
from app.modules.classes.models import SchoolClass
from app.modules.students.models import (
    ClassStudent,
    GroupMember,
    SeatingPlan,
    SeatingPlanMember,
    Student,
    StudentActivityLog,
    StudentGroup,
    StudentNote,
)
from app.modules.students.schemas import (
    ClassEnrollRequest,
    EnrolledClassItem,
    SeatingPlanCreate,
    SeatingPlanMemberOut,
    SeatingPlanOut,
    StudentActivityLogCreate,
    StudentActivityLogOut,
    StudentCreate,
    StudentDetailOut,
    StudentGroupCreate,
    StudentGroupMemberOut,
    StudentGroupOut,
    StudentNoteCreate,
    StudentNoteOut,
    StudentOut,
    StudentUpdate,
)
from app.shared.deps import Principal, current_principal

router = APIRouter(tags=["students"])


def _get_student_classes(db: Session, student_id: uuid.UUID) -> list[EnrolledClassItem]:
    stmt = (
        select(SchoolClass.id, SchoolClass.name)
        .join(ClassStudent, ClassStudent.class_id == SchoolClass.id)
        .where(
            ClassStudent.student_id == student_id,
            ClassStudent.deleted_at.is_(None),
            SchoolClass.deleted_at.is_(None),
        )
    )
    rows = db.execute(stmt).all()
    return [EnrolledClassItem(id=r[0], name=r[1]) for r in rows]


@router.get("/students", response_model=list[StudentOut])
def list_students(
    class_id: uuid.UUID | None = Query(None),
    search: str | None = Query(None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    query = select(Student).where(
        Student.teacher_id == tid,
        Student.deleted_at.is_(None),
        Student.archived_at.is_(None),
    )

    if class_id:
        query = query.join(ClassStudent, ClassStudent.student_id == Student.id).where(
            ClassStudent.class_id == class_id,
            ClassStudent.deleted_at.is_(None),
        )

    if search:
        pattern = f"%{search.strip()}%"
        query = query.where(
            or_(
                Student.first_name.ilike(pattern),
                Student.last_name.ilike(pattern),
                Student.external_ref.ilike(pattern),
            )
        )

    query = query.order_by(Student.last_name, Student.first_name)
    students = db.scalars(query).all()

    res = []
    for s in students:
        classes = _get_student_classes(db, s.id)
        res.append(
            StudentOut(
                id=s.id,
                first_name=s.first_name,
                last_name=s.last_name,
                external_ref=s.external_ref,
                classes=classes,
                version=s.version,
                created_at=s.created_at,
            )
        )
    return res


@router.post("/students", response_model=StudentOut)
def create_student(
    req: StudentCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id or not principal.school_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    sid = uuid.UUID(principal.school_id)

    student = Student(
        teacher_id=tid,
        school_id=sid,
        first_name=req.first_name.strip(),
        last_name=req.last_name.strip(),
        external_ref=req.external_ref.strip() if req.external_ref else None,
    )
    db.add(student)
    db.flush()

    enrolled = []
    if req.class_id:
        cls = db.scalar(
            select(SchoolClass).where(
                SchoolClass.id == req.class_id,
                SchoolClass.teacher_id == tid,
                SchoolClass.deleted_at.is_(None),
            )
        )
        if not cls:
            raise NotFound("Class not found.")
        link = ClassStudent(teacher_id=tid, class_id=cls.id, student_id=student.id)
        db.add(link)
        db.flush()
        enrolled.append(EnrolledClassItem(id=cls.id, name=cls.name))

    return StudentOut(
        id=student.id,
        first_name=student.first_name,
        last_name=student.last_name,
        external_ref=student.external_ref,
        classes=enrolled,
        version=student.version,
        created_at=student.created_at,
    )


@router.get("/students/{student_id}", response_model=StudentDetailOut)
def get_student(
    student_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Student not found.")
    tid = uuid.UUID(principal.teacher_id)

    student = db.scalar(
        select(Student).where(
            Student.id == student_id,
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
        )
    )
    if not student:
        raise NotFound("Student not found.")

    classes = _get_student_classes(db, student.id)

    notes_rows = db.scalars(
        select(StudentNote)
        .where(
            StudentNote.student_id == student.id,
            StudentNote.teacher_id == tid,
            StudentNote.deleted_at.is_(None),
        )
        .order_by(StudentNote.created_at.desc())
    ).all()

    notes = [
        StudentNoteOut(
            id=n.id,
            body=n.body,
            class_id=n.class_id,
            created_at=n.created_at,
        )
        for n in notes_rows
    ]

    return StudentDetailOut(
        id=student.id,
        first_name=student.first_name,
        last_name=student.last_name,
        external_ref=student.external_ref,
        classes=classes,
        version=student.version,
        created_at=student.created_at,
        notes=notes,
    )


@router.patch("/students/{student_id}", response_model=StudentOut)
def update_student(
    student_id: uuid.UUID,
    req: StudentUpdate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Student not found.")
    tid = uuid.UUID(principal.teacher_id)

    student = db.scalar(
        select(Student).where(
            Student.id == student_id,
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
        )
    )
    if not student:
        raise NotFound("Student not found.")

    if student.version != req.base_version:
        raise Conflict("Conflict: student was updated by another change.", details={"current_version": student.version})

    if req.first_name is not None:
        student.first_name = req.first_name.strip()
    if req.last_name is not None:
        student.last_name = req.last_name.strip()
    if req.external_ref is not None:
        student.external_ref = req.external_ref.strip() if req.external_ref else None

    student.version += 1
    db.flush()

    classes = _get_student_classes(db, student.id)
    return StudentOut(
        id=student.id,
        first_name=student.first_name,
        last_name=student.last_name,
        external_ref=student.external_ref,
        classes=classes,
        version=student.version,
        created_at=student.created_at,
    )


@router.delete("/students/{student_id}")
def delete_student(
    student_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Student not found.")
    tid = uuid.UUID(principal.teacher_id)

    student = db.scalar(
        select(Student).where(
            Student.id == student_id,
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
        )
    )
    if not student:
        raise NotFound("Student not found.")

    now = datetime.now(timezone.utc)
    student.deleted_at = now
    student.version += 1
    db.flush()
    return {"message": "Student deleted successfully."}


# ---------------- Enrollments & Notes ----------------

@router.post("/classes/{class_id}/students", response_model=EnrolledClassItem)
def enroll_student_in_class(
    class_id: uuid.UUID,
    req: ClassEnrollRequest,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Class not found.")
    tid = uuid.UUID(principal.teacher_id)

    cls = db.scalar(
        select(SchoolClass).where(
            SchoolClass.id == class_id,
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
        )
    )
    if not cls:
        raise NotFound("Class not found.")

    student = db.scalar(
        select(Student).where(
            Student.id == req.student_id,
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
        )
    )
    if not student:
        raise NotFound("Student not found.")

    existing = db.scalar(
        select(ClassStudent).where(
            ClassStudent.class_id == cls.id,
            ClassStudent.student_id == student.id,
            ClassStudent.deleted_at.is_(None),
        )
    )
    if not existing:
        link = ClassStudent(teacher_id=tid, class_id=cls.id, student_id=student.id)
        db.add(link)
        db.flush()

    return EnrolledClassItem(id=cls.id, name=cls.name)


@router.delete("/classes/{class_id}/students/{student_id}")
def unenroll_student_from_class(
    class_id: uuid.UUID,
    student_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Class not found.")
    tid = uuid.UUID(principal.teacher_id)

    link = db.scalar(
        select(ClassStudent).where(
            ClassStudent.class_id == class_id,
            ClassStudent.student_id == student_id,
            ClassStudent.teacher_id == tid,
            ClassStudent.deleted_at.is_(None),
        )
    )
    if not link:
        raise NotFound("Student is not enrolled in this class.")

    link.deleted_at = datetime.now(timezone.utc)
    link.version += 1
    db.flush()
    return {"message": "Student unenrolled successfully."}


@router.post("/students/{student_id}/notes", response_model=StudentNoteOut)
def add_student_note(
    student_id: uuid.UUID,
    req: StudentNoteCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Student not found.")
    tid = uuid.UUID(principal.teacher_id)

    student = db.scalar(
        select(Student).where(
            Student.id == student_id,
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
        )
    )
    if not student:
        raise NotFound("Student not found.")

    note = StudentNote(
        teacher_id=tid,
        student_id=student.id,
        class_id=req.class_id,
        body=req.body.strip(),
    )
    db.add(note)
    db.flush()

    return StudentNoteOut(
        id=note.id,
        body=note.body,
        class_id=note.class_id,
        created_at=note.created_at,
    )


# --- Phase 3: Seating Plans ---

@router.get("/classes/{class_id}/seating-plans", response_model=list[SeatingPlanOut])
def list_seating_plans(
    class_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    plans = db.execute(
        select(SeatingPlan).where(
            SeatingPlan.class_id == class_id,
            SeatingPlan.teacher_id == tid,
            SeatingPlan.deleted_at.is_(None),
        ).order_by(SeatingPlan.created_at.desc())
    ).scalars().all()

    result = []
    for p in plans:
        members_stmt = (
            select(SeatingPlanMember, Student.first_name, Student.last_name)
            .outerjoin(Student, Student.id == SeatingPlanMember.student_id)
            .where(SeatingPlanMember.plan_id == p.id, SeatingPlanMember.deleted_at.is_(None))
        )
        mem_rows = db.execute(members_stmt).all()
        members_out = [
            SeatingPlanMemberOut(
                id=m[0].id,
                plan_id=m[0].plan_id,
                student_id=m[0].student_id,
                student_name=f"{m[1]} {m[2]}" if m[1] else None,
                seat_x=float(m[0].seat_x),
                seat_y=float(m[0].seat_y),
            )
            for m in mem_rows
        ]
        result.append(
            SeatingPlanOut(
                id=p.id,
                class_id=p.class_id,
                name=p.name,
                layout=p.layout,
                members=members_out,
                version=p.version,
                created_at=p.created_at,
                updated_at=p.updated_at,
            )
        )
    return result


@router.post("/classes/{class_id}/seating-plans", response_model=SeatingPlanOut, status_code=201)
def create_seating_plan(
    class_id: uuid.UUID,
    payload: SeatingPlanCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    cls = db.execute(
        select(SchoolClass).where(
            SchoolClass.id == class_id,
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not cls:
        raise NotFound("Class not found.")

    plan = SeatingPlan(
        teacher_id=tid,
        class_id=class_id,
        name=payload.name.strip(),
        layout=payload.layout,
    )
    db.add(plan)
    db.flush()

    members_out = []
    for m in payload.members:
        member = SeatingPlanMember(
            teacher_id=tid,
            plan_id=plan.id,
            student_id=m.student_id,
            seat_x=m.seat_x,
            seat_y=m.seat_y,
        )
        db.add(member)
        db.flush()

        s_name = None
        if m.student_id:
            st = db.execute(select(Student).where(Student.id == m.student_id)).scalar_one_or_none()
            if st:
                s_name = f"{st.first_name} {st.last_name}"

        members_out.append(
            SeatingPlanMemberOut(
                id=member.id,
                plan_id=plan.id,
                student_id=m.student_id,
                student_name=s_name,
                seat_x=float(member.seat_x),
                seat_y=float(member.seat_y),
            )
        )

    db.commit()
    db.refresh(plan)
    return SeatingPlanOut(
        id=plan.id,
        class_id=plan.class_id,
        name=plan.name,
        layout=plan.layout,
        members=members_out,
        version=plan.version,
        created_at=plan.created_at,
        updated_at=plan.updated_at,
    )


# --- Phase 3: Student Groups ---

@router.get("/classes/{class_id}/groups", response_model=list[StudentGroupOut])
def list_student_groups(
    class_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    groups = db.execute(
        select(StudentGroup).where(
            StudentGroup.class_id == class_id,
            StudentGroup.teacher_id == tid,
            StudentGroup.deleted_at.is_(None),
        ).order_by(StudentGroup.name.asc())
    ).scalars().all()

    result = []
    for g in groups:
        mem_stmt = (
            select(GroupMember, Student.first_name, Student.last_name)
            .join(Student, Student.id == GroupMember.student_id)
            .where(GroupMember.group_id == g.id, GroupMember.deleted_at.is_(None))
        )
        mem_rows = db.execute(mem_stmt).all()
        members_out = [
            StudentGroupMemberOut(
                id=m[0].id,
                student_id=m[0].student_id,
                student_name=f"{m[1]} {m[2]}",
            )
            for m in mem_rows
        ]
        result.append(
            StudentGroupOut(
                id=g.id,
                class_id=g.class_id,
                name=g.name,
                members=members_out,
                version=g.version,
                created_at=g.created_at,
            )
        )
    return result


@router.post("/classes/{class_id}/groups", response_model=StudentGroupOut, status_code=201)
def create_student_group(
    class_id: uuid.UUID,
    payload: StudentGroupCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    group = StudentGroup(
        teacher_id=tid,
        class_id=class_id,
        name=payload.name.strip(),
    )
    db.add(group)
    db.flush()

    members_out = []
    for sid in payload.student_ids:
        gm = GroupMember(
            teacher_id=tid,
            group_id=group.id,
            student_id=sid,
        )
        db.add(gm)
        db.flush()
        st = db.execute(select(Student).where(Student.id == sid)).scalar_one_or_none()
        st_name = f"{st.first_name} {st.last_name}" if st else "Student"
        members_out.append(
            StudentGroupMemberOut(
                id=gm.id,
                student_id=sid,
                student_name=st_name,
            )
        )

    db.commit()
    db.refresh(group)
    return StudentGroupOut(
        id=group.id,
        class_id=group.class_id,
        name=group.name,
        members=members_out,
        version=group.version,
        created_at=group.created_at,
    )


# --- Phase 3: Student Activity / Participation Log ---

@router.get("/classes/{class_id}/activity-logs", response_model=list[StudentActivityLogOut])
def list_student_activity_logs(
    class_id: uuid.UUID,
    student_id: uuid.UUID | None = Query(None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    stmt = (
        select(StudentActivityLog, Student.first_name, Student.last_name)
        .join(Student, Student.id == StudentActivityLog.student_id)
        .where(
            StudentActivityLog.class_id == class_id,
            StudentActivityLog.teacher_id == tid,
            StudentActivityLog.deleted_at.is_(None),
        )
    )
    if student_id:
        stmt = stmt.where(StudentActivityLog.student_id == student_id)

    rows = db.execute(stmt.order_by(StudentActivityLog.logged_on.desc())).all()
    return [
        StudentActivityLogOut(
            id=r[0].id,
            student_id=r[0].student_id,
            student_name=f"{r[1]} {r[2]}",
            class_id=r[0].class_id,
            logged_on=datetime(r[0].logged_on.year, r[0].logged_on.month, r[0].logged_on.day, tzinfo=timezone.utc),
            category=r[0].category,
            note=r[0].note,
            created_at=r[0].created_at,
        )
        for r in rows
    ]


@router.post("/classes/{class_id}/activity-logs", response_model=StudentActivityLogOut, status_code=201)
def create_student_activity_log(
    class_id: uuid.UUID,
    payload: StudentActivityLogCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    st = db.execute(
        select(Student).where(
            Student.id == payload.student_id,
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not st:
        raise NotFound("Student not found.")

    log_date = payload.logged_on.date() if payload.logged_on else datetime.now(timezone.utc).date()

    entry = StudentActivityLog(
        teacher_id=tid,
        student_id=payload.student_id,
        class_id=class_id,
        logged_on=log_date,
        category=payload.category,
        note=payload.note,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)

    return StudentActivityLogOut(
        id=entry.id,
        student_id=entry.student_id,
        student_name=f"{st.first_name} {st.last_name}",
        class_id=entry.class_id,
        logged_on=datetime(entry.logged_on.year, entry.logged_on.month, entry.logged_on.day, tzinfo=timezone.utc),
        category=entry.category,
        note=entry.note,
        created_at=entry.created_at,
    )
