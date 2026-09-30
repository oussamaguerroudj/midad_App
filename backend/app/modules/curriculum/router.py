import uuid
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.audit_model import AuditLog
from app.core.database import get_db
from app.core.exceptions import NotFound
from app.modules.curriculum.models import CurriculumLesson, CurriculumProgress, CurriculumUnit
from app.modules.curriculum.schemas import (
    CurriculumLessonCreate,
    CurriculumLessonOut,
    CurriculumProgressOut,
    CurriculumProgressUpdate,
    CurriculumUnitCreate,
    CurriculumUnitOut,
)
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/curriculum", tags=["curriculum"])


@router.post("/units", response_model=CurriculumUnitOut, status_code=status.HTTP_201_CREATED)
def create_unit(
    payload: CurriculumUnitCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> CurriculumUnitOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    unit = CurriculumUnit(
        teacher_id=tid,
        subject_id=payload.subject_id,
        level=payload.level,
        title=payload.title,
        position=payload.position,
        version=1,
    )
    db.add(unit)
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="curriculum_unit_create",
            entity_type="curriculum_unit",
            entity_id=unit.id,
            after={"title": unit.title, "level": unit.level},
        )
    )
    db.commit()

    return CurriculumUnitOut(
        id=unit.id,
        subject_id=unit.subject_id,
        level=unit.level,
        title=unit.title,
        position=unit.position,
        lessons=[],
    )


@router.post("/lessons", response_model=CurriculumLessonOut, status_code=status.HTTP_201_CREATED)
def create_curriculum_lesson(
    payload: CurriculumLessonCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> CurriculumLessonOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    unit = db.scalar(
        select(CurriculumUnit).where(
            CurriculumUnit.id == payload.unit_id,
            CurriculumUnit.teacher_id == tid,
            CurriculumUnit.deleted_at.is_(None),
        )
    )
    if not unit:
        raise NotFound("Curriculum unit not found")

    cur_lesson = CurriculumLesson(
        teacher_id=tid,
        unit_id=payload.unit_id,
        title=payload.title,
        position=payload.position,
        version=1,
    )
    db.add(cur_lesson)
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="curriculum_lesson_create",
            entity_type="curriculum_lesson",
            entity_id=cur_lesson.id,
            after={"title": cur_lesson.title, "unit_id": str(unit.id)},
        )
    )
    db.commit()

    return CurriculumLessonOut(
        id=cur_lesson.id,
        unit_id=cur_lesson.unit_id,
        title=cur_lesson.title,
        position=cur_lesson.position,
        progress_status="not_started",
    )


@router.get("/units", response_model=list[CurriculumUnitOut])
def get_curriculum_units(
    subject_id: uuid.UUID | None = Query(default=None),
    level: str | None = Query(default=None),
    class_id: uuid.UUID | None = Query(default=None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> list[CurriculumUnitOut]:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    q = select(CurriculumUnit).where(
        CurriculumUnit.teacher_id == tid,
        CurriculumUnit.deleted_at.is_(None),
    )
    if subject_id:
        q = q.where(CurriculumUnit.subject_id == subject_id)
    if level:
        q = q.where(CurriculumUnit.level == level)
    q = q.order_by(CurriculumUnit.position.asc(), CurriculumUnit.created_at.asc())

    units = list(db.scalars(q).all())
    if not units:
        return []

    unit_ids = [u.id for u in units]
    lessons_q = (
        select(CurriculumLesson)
        .where(
            CurriculumLesson.unit_id.in_(unit_ids),
            CurriculumLesson.teacher_id == tid,
            CurriculumLesson.deleted_at.is_(None),
        )
        .order_by(CurriculumLesson.position.asc())
    )
    all_lessons = list(db.scalars(lessons_q).all())

    progress_map: dict[uuid.UUID, str] = {}
    if class_id:
        prog_q = select(CurriculumProgress).where(
            CurriculumProgress.class_id == class_id,
            CurriculumProgress.teacher_id == tid,
        )
        for prog in db.scalars(prog_q).all():
            progress_map[prog.curriculum_lesson_id] = prog.status

    unit_lessons_map: dict[uuid.UUID, list[CurriculumLessonOut]] = {u.id: [] for u in units}
    for l in all_lessons:
        st = progress_map.get(l.id, "not_started")
        unit_lessons_map[l.unit_id].append(
            CurriculumLessonOut(
                id=l.id,
                unit_id=l.unit_id,
                title=l.title,
                position=l.position,
                progress_status=st,
            )
        )

    return [
        CurriculumUnitOut(
            id=u.id,
            subject_id=u.subject_id,
            level=u.level,
            title=u.title,
            position=u.position,
            lessons=unit_lessons_map.get(u.id, []),
        )
        for u in units
    ]


@router.post("/progress", response_model=CurriculumProgressOut)
def update_curriculum_progress(
    payload: CurriculumProgressUpdate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> CurriculumProgressOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    prog = db.scalar(
        select(CurriculumProgress).where(
            CurriculumProgress.class_id == payload.class_id,
            CurriculumProgress.curriculum_lesson_id == payload.curriculum_lesson_id,
            CurriculumProgress.teacher_id == tid,
        )
    )
    if prog:
        prog.status = payload.status
        prog.version += 1
    else:
        prog = CurriculumProgress(
            teacher_id=tid,
            class_id=payload.class_id,
            curriculum_lesson_id=payload.curriculum_lesson_id,
            academic_year_id=payload.academic_year_id,
            status=payload.status,
            version=1,
        )
        db.add(prog)

    db.flush()
    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="update_curriculum_progress",
            entity_type="curriculum_progress",
            entity_id=prog.id,
            after={"status": prog.status, "class_id": str(prog.class_id)},
        )
    )
    db.commit()

    return CurriculumProgressOut(
        id=prog.id,
        class_id=prog.class_id,
        curriculum_lesson_id=prog.curriculum_lesson_id,
        academic_year_id=prog.academic_year_id,
        status=prog.status,
        updated_at=prog.updated_at,
    )
