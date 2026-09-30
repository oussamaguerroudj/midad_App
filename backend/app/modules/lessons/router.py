import uuid
from datetime import date, datetime, timezone
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.audit_model import AuditLog
from app.core.database import get_db
from app.core.exceptions import Conflict, NotFound
from app.modules.lessons.models import Lesson
from app.modules.lessons.schemas import LessonCreate, LessonOut, LessonUpdate
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/lessons", tags=["lessons"])


@router.post("", response_model=LessonOut, status_code=status.HTTP_201_CREATED)
def create_lesson(
    payload: LessonCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> LessonOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    lesson = Lesson(
        teacher_id=tid,
        class_id=payload.class_id,
        subject_id=payload.subject_id,
        academic_year_id=payload.academic_year_id,
        curriculum_lesson_id=payload.curriculum_lesson_id,
        topic=payload.topic,
        lesson_date=payload.lesson_date,
        duration_min=payload.duration_min,
        objectives=payload.objectives,
        content=payload.content,
        activities=payload.activities,
        homework=payload.homework,
        notes=payload.notes,
        journal_covered=payload.journal_covered,
        completion=payload.completion,
        version=1,
    )
    db.add(lesson)
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="lesson_create",
            entity_type="lesson",
            entity_id=lesson.id,
            after={"topic": lesson.topic, "completion": lesson.completion},
        )
    )
    db.commit()
    return lesson


@router.get("", response_model=list[LessonOut])
def list_lessons(
    class_id: uuid.UUID | None = Query(default=None),
    from_date: date | None = Query(default=None),
    to_date: date | None = Query(default=None),
    completion: str | None = Query(default=None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> list[LessonOut]:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    q = select(Lesson).where(Lesson.teacher_id == tid, Lesson.deleted_at.is_(None))
    if class_id:
        q = q.where(Lesson.class_id == class_id)
    if from_date:
        q = q.where(Lesson.lesson_date >= from_date)
    if to_date:
        q = q.where(Lesson.lesson_date <= to_date)
    if completion:
        q = q.where(Lesson.completion == completion)

    q = q.order_by(Lesson.lesson_date.desc(), Lesson.created_at.desc())
    return list(db.scalars(q).all())


@router.get("/{lesson_id}", response_model=LessonOut)
def get_lesson(
    lesson_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> LessonOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    lesson = db.scalar(
        select(Lesson).where(
            Lesson.id == lesson_id,
            Lesson.teacher_id == tid,
            Lesson.deleted_at.is_(None),
        )
    )
    if not lesson:
        raise NotFound("Lesson not found")
    return lesson


@router.patch("/{lesson_id}", response_model=LessonOut)
def update_lesson(
    lesson_id: uuid.UUID,
    payload: LessonUpdate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> LessonOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    lesson = db.scalar(
        select(Lesson).where(
            Lesson.id == lesson_id,
            Lesson.teacher_id == tid,
            Lesson.deleted_at.is_(None),
        )
    )
    if not lesson:
        raise NotFound("Lesson not found")

    if lesson.version != payload.base_version:
        raise Conflict(f"Version conflict: current {lesson.version} != client {payload.base_version}")

    before = {"topic": lesson.topic, "completion": lesson.completion, "journal_covered": lesson.journal_covered}

    if payload.topic is not None:
        lesson.topic = payload.topic
    if payload.class_id is not None:
        lesson.class_id = payload.class_id
    if payload.lesson_date is not None:
        lesson.lesson_date = payload.lesson_date
    if payload.duration_min is not None:
        lesson.duration_min = payload.duration_min
    if payload.objectives is not None:
        lesson.objectives = payload.objectives
    if payload.content is not None:
        lesson.content = payload.content
    if payload.activities is not None:
        lesson.activities = payload.activities
    if payload.homework is not None:
        lesson.homework = payload.homework
    if payload.notes is not None:
        lesson.notes = payload.notes
    if payload.journal_covered is not None:
        lesson.journal_covered = payload.journal_covered
    if payload.completion is not None:
        lesson.completion = payload.completion

    lesson.version += 1
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="lesson_update",
            entity_type="lesson",
            entity_id=lesson.id,
            before=before,
            after={"topic": lesson.topic, "completion": lesson.completion, "journal_covered": lesson.journal_covered},
        )
    )
    db.commit()
    return lesson


@router.delete("/{lesson_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_lesson(
    lesson_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> None:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    lesson = db.scalar(
        select(Lesson).where(
            Lesson.id == lesson_id,
            Lesson.teacher_id == tid,
            Lesson.deleted_at.is_(None),
        )
    )
    if not lesson:
        raise NotFound("Lesson not found")

    lesson.deleted_at = datetime.now(timezone.utc)
    lesson.version += 1
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="lesson_delete",
            entity_type="lesson",
            entity_id=lesson.id,
        )
    )
    db.commit()
