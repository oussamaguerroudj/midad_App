import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import AppError, Conflict, NotFound
from app.modules.academic_years.models import AcademicYear
from app.modules.classes.models import SchoolClass, Subject, TeacherClass
from app.modules.classes.schemas import (
    ClassCreate,
    ClassDetailOut,
    ClassOut,
    ClassStudentItem,
    ClassUpdate,
    SubjectCreate,
    SubjectOut,
)
from app.modules.students.models import ClassStudent, Student
from app.shared.deps import Principal, current_principal

router = APIRouter(tags=["classes"])


# ---------------- Subjects ----------------

@router.get("/subjects", response_model=list[SubjectOut])
def list_subjects(principal: Principal = Depends(current_principal), db: Session = Depends(get_db)):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    stmt = (
        select(Subject)
        .where(Subject.teacher_id == tid, Subject.deleted_at.is_(None))
        .order_by(Subject.name)
    )
    subjects = db.scalars(stmt).all()
    return [SubjectOut(id=s.id, name=s.name, code=s.code, version=s.version) for s in subjects]


@router.post("/subjects", response_model=SubjectOut)
def create_subject(req: SubjectCreate, principal: Principal = Depends(current_principal), db: Session = Depends(get_db)):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    name = req.name.strip()
    existing = db.scalar(
        select(Subject).where(Subject.teacher_id == tid, Subject.name == name, Subject.deleted_at.is_(None))
    )
    if existing:
        return SubjectOut(id=existing.id, name=existing.name, code=existing.code, version=existing.version)

    subject = Subject(teacher_id=tid, name=name, code=req.code)
    db.add(subject)
    db.flush()
    return SubjectOut(id=subject.id, name=subject.name, code=subject.code, version=subject.version)


# ---------------- Classes ----------------

@router.get("/classes", response_model=list[ClassOut])
def list_classes(
    academic_year_id: uuid.UUID | None = Query(None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    # Subquery for student count
    count_subq = (
        select(ClassStudent.class_id, func.count(ClassStudent.id).label("cnt"))
        .where(ClassStudent.teacher_id == tid, ClassStudent.deleted_at.is_(None))
        .group_by(ClassStudent.class_id)
        .subquery()
    )

    query = (
        select(SchoolClass, Subject.name.label("subject_name"), func.coalesce(count_subq.c.cnt, 0).label("cnt"))
        .join(Subject, Subject.id == SchoolClass.subject_id)
        .outerjoin(count_subq, count_subq.c.class_id == SchoolClass.id)
        .where(
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
            SchoolClass.archived_at.is_(None),
        )
    )

    if academic_year_id:
        query = query.where(SchoolClass.academic_year_id == academic_year_id)

    query = query.order_by(SchoolClass.name)
    results = db.execute(query).all()

    return [
        ClassOut(
            id=cls.id,
            name=cls.name,
            level=cls.level,
            subject_id=cls.subject_id,
            subject_name=subj_name,
            academic_year_id=cls.academic_year_id,
            student_count=cnt,
            version=cls.version,
            created_at=cls.created_at,
        )
        for cls, subj_name, cnt in results
    ]


@router.post("/classes", response_model=ClassOut)
def create_class(req: ClassCreate, principal: Principal = Depends(current_principal), db: Session = Depends(get_db)):
    if not principal.teacher_id or not principal.school_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    sid = uuid.UUID(principal.school_id)

    # Resolve or create subject
    subject_id = req.subject_id
    subject_name = ""
    if subject_id:
        subj = db.scalar(select(Subject).where(Subject.id == subject_id, Subject.teacher_id == tid))
        if not subj:
            raise NotFound("Subject not found.")
        subject_name = subj.name
    elif req.subject_name:
        subj_name = req.subject_name.strip()
        subj = db.scalar(
            select(Subject).where(Subject.teacher_id == tid, Subject.name == subj_name, Subject.deleted_at.is_(None))
        )
        if not subj:
            subj = Subject(teacher_id=tid, name=subj_name)
            db.add(subj)
            db.flush()
        subject_id = subj.id
        subject_name = subj.name
    else:
        # Default subject
        subj = db.scalar(select(Subject).where(Subject.teacher_id == tid, Subject.deleted_at.is_(None)))
        if not subj:
            subj = Subject(teacher_id=tid, name="المادة العامة")
            db.add(subj)
            db.flush()
        subject_id = subj.id
        subject_name = subj.name

    # Resolve academic year
    year_id = req.academic_year_id
    if not year_id:
        current_year = db.scalar(
            select(AcademicYear).where(
                AcademicYear.teacher_id == tid,
                AcademicYear.is_current.is_(True),
                AcademicYear.deleted_at.is_(None),
            )
        )
        if not current_year:
            # Create a default current year
            today = datetime.now(timezone.utc).date()
            start_yr = today.year if today.month >= 9 else today.year - 1
            current_year = AcademicYear(
                school_id=sid,
                teacher_id=tid,
                label=f"{start_yr}-{start_yr + 1}",
                starts_on=today,
                ends_on=today,
                is_current=True,
            )
            db.add(current_year)
            db.flush()
        year_id = current_year.id

    # Check unique constraint (teacher_id, academic_year_id, subject_id, name)
    existing_cls = db.scalar(
        select(SchoolClass).where(
            SchoolClass.teacher_id == tid,
            SchoolClass.academic_year_id == year_id,
            SchoolClass.subject_id == subject_id,
            SchoolClass.name == req.name.strip(),
            SchoolClass.deleted_at.is_(None),
        )
    )
    if existing_cls:
        raise AppError("Class with this name and subject already exists this academic year.")

    cls = SchoolClass(
        teacher_id=tid,
        school_id=sid,
        academic_year_id=year_id,
        subject_id=subject_id,
        name=req.name.strip(),
        level=req.level.strip() if req.level else None,
    )
    db.add(cls)
    db.flush()

    tc = TeacherClass(teacher_id=tid, class_id=cls.id, role="owner")
    db.add(tc)
    db.flush()

    return ClassOut(
        id=cls.id,
        name=cls.name,
        level=cls.level,
        subject_id=cls.subject_id,
        subject_name=subject_name,
        academic_year_id=cls.academic_year_id,
        student_count=0,
        version=cls.version,
        created_at=cls.created_at,
    )


@router.get("/classes/{class_id}", response_model=ClassDetailOut)
def get_class(class_id: uuid.UUID, principal: Principal = Depends(current_principal), db: Session = Depends(get_db)):
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

    subj = db.scalar(select(Subject).where(Subject.id == cls.subject_id))
    subj_name = subj.name if subj else ""

    # Fetch enrolled students
    students_query = (
        select(Student)
        .join(ClassStudent, ClassStudent.student_id == Student.id)
        .where(
            ClassStudent.class_id == cls.id,
            ClassStudent.deleted_at.is_(None),
            Student.deleted_at.is_(None),
        )
        .order_by(Student.last_name, Student.first_name)
    )
    students = db.scalars(students_query).all()

    items = [
        ClassStudentItem(
            id=s.id,
            first_name=s.first_name,
            last_name=s.last_name,
            external_ref=s.external_ref,
        )
        for s in students
    ]

    return ClassDetailOut(
        id=cls.id,
        name=cls.name,
        level=cls.level,
        subject_id=cls.subject_id,
        subject_name=subj_name,
        academic_year_id=cls.academic_year_id,
        student_count=len(items),
        version=cls.version,
        created_at=cls.created_at,
        students=items,
    )


@router.patch("/classes/{class_id}", response_model=ClassOut)
def update_class(
    class_id: uuid.UUID,
    req: ClassUpdate,
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

    # Optimistic lock check
    if cls.version != req.base_version:
        raise Conflict("Conflict: class has been modified by another change.", details={"current_version": cls.version})

    if req.name is not None:
        cls.name = req.name.strip()
    if req.level is not None:
        cls.level = req.level.strip()
    if req.subject_id is not None:
        subj = db.scalar(select(Subject).where(Subject.id == req.subject_id, Subject.teacher_id == tid))
        if not subj:
            raise NotFound("Subject not found.")
        cls.subject_id = req.subject_id

    cls.version += 1
    db.flush()

    subj = db.scalar(select(Subject).where(Subject.id == cls.subject_id))
    cnt = db.scalar(
        select(func.count(ClassStudent.id)).where(ClassStudent.class_id == cls.id, ClassStudent.deleted_at.is_(None))
    ) or 0

    return ClassOut(
        id=cls.id,
        name=cls.name,
        level=cls.level,
        subject_id=cls.subject_id,
        subject_name=subj.name if subj else "",
        academic_year_id=cls.academic_year_id,
        student_count=cnt,
        version=cls.version,
        created_at=cls.created_at,
    )


@router.delete("/classes/{class_id}")
def delete_class(class_id: uuid.UUID, principal: Principal = Depends(current_principal), db: Session = Depends(get_db)):
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

    now = datetime.now(timezone.utc)
    cls.deleted_at = now
    cls.version += 1
    db.flush()
    return {"message": "Class deleted successfully."}
