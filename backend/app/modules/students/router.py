import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import AppError, Conflict, NotFound
from app.modules.classes.models import SchoolClass
from app.modules.students.models import ClassStudent, Student, StudentNote
from app.modules.students.schemas import (
    ClassEnrollRequest,
    EnrolledClassItem,
    StudentCreate,
    StudentDetailOut,
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
