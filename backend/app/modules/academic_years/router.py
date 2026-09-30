import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import AppError, Conflict, NotFound
from app.modules.academic_years.models import AcademicYear
from app.modules.academic_years.schemas import (
    AcademicYearCreate,
    AcademicYearOut,
    AcademicYearUpdate,
)
from app.modules.schools.models import School
from app.modules.users.models import Teacher
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/academic-years", tags=["academic-years"])


@router.get("", response_model=list[AcademicYearOut])
def list_academic_years(
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    stmt = (
        select(AcademicYear)
        .where(
            AcademicYear.teacher_id == tid,
            AcademicYear.deleted_at.is_(None),
        )
        .order_by(AcademicYear.starts_on.desc())
    )
    return db.execute(stmt).scalars().all()


@router.get("/current", response_model=AcademicYearOut | None)
def get_current_academic_year(
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    stmt = select(AcademicYear).where(
        AcademicYear.teacher_id == tid,
        AcademicYear.is_current.is_(True),
        AcademicYear.deleted_at.is_(None),
    )
    return db.execute(stmt).scalar_one_or_none()


@router.post("", response_model=AcademicYearOut, status_code=201)
def create_academic_year(
    payload: AcademicYearCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    if payload.ends_on <= payload.starts_on:
        raise AppError(code="VALIDATION", message="ends_on must be after starts_on.")

    # Determine school_id
    school_id = payload.school_id
    if not school_id:
        teacher = db.execute(select(Teacher).where(Teacher.id == tid)).scalar_one_or_none()
        if teacher:
            school_id = teacher.school_id
        else:
            first_school = db.execute(select(School).where(School.deleted_at.is_(None))).scalars().first()
            if not first_school:
                first_school = School(name="Default School")
                db.add(first_school)
                db.flush()
            school_id = first_school.id

    # Check unique label
    existing = db.execute(
        select(AcademicYear).where(
            AcademicYear.teacher_id == tid,
            AcademicYear.label == payload.label,
            AcademicYear.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if existing:
        raise Conflict(f"Academic year '{payload.label}' already exists.")

    if payload.is_current:
        # Unset previous current
        db.execute(
            update(AcademicYear)
            .where(AcademicYear.teacher_id == tid, AcademicYear.is_current.is_(True))
            .values(is_current=False)
        )

    ay = AcademicYear(
        school_id=school_id,
        teacher_id=tid,
        label=payload.label,
        starts_on=payload.starts_on,
        ends_on=payload.ends_on,
        is_current=payload.is_current,
    )
    db.add(ay)
    db.commit()
    db.refresh(ay)
    return ay


@router.put("/{year_id}", response_model=AcademicYearOut)
def update_academic_year(
    year_id: uuid.UUID,
    payload: AcademicYearUpdate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    ay = db.execute(
        select(AcademicYear).where(
            AcademicYear.id == year_id,
            AcademicYear.teacher_id == tid,
            AcademicYear.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not ay:
        raise NotFound("Academic year not found.")

    if payload.label is not None:
        ay.label = payload.label
    if payload.starts_on is not None:
        ay.starts_on = payload.starts_on
    if payload.ends_on is not None:
        ay.ends_on = payload.ends_on

    if ay.ends_on <= ay.starts_on:
        raise AppError(code="VALIDATION", message="ends_on must be after starts_on.")

    if payload.is_current is True and not ay.is_current:
        db.execute(
            update(AcademicYear)
            .where(AcademicYear.teacher_id == tid, AcademicYear.is_current.is_(True))
            .values(is_current=False)
        )
        ay.is_current = True
    elif payload.is_current is False:
        ay.is_current = False

    ay.version += 1
    ay.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(ay)
    return ay


@router.post("/{year_id}/set-current", response_model=AcademicYearOut)
def set_current_academic_year(
    year_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    ay = db.execute(
        select(AcademicYear).where(
            AcademicYear.id == year_id,
            AcademicYear.teacher_id == tid,
            AcademicYear.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not ay:
        raise NotFound("Academic year not found.")

    db.execute(
        update(AcademicYear)
        .where(AcademicYear.teacher_id == tid, AcademicYear.is_current.is_(True))
        .values(is_current=False)
    )
    ay.is_current = True
    ay.version += 1
    ay.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(ay)
    return ay


@router.delete("/{year_id}", status_code=204)
def delete_academic_year(
    year_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    ay = db.execute(
        select(AcademicYear).where(
            AcademicYear.id == year_id,
            AcademicYear.teacher_id == tid,
            AcademicYear.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not ay:
        raise NotFound("Academic year not found.")

    ay.deleted_at = datetime.now(timezone.utc)
    db.commit()
    return None
