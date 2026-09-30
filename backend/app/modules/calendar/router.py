import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.audit_model import AuditLog
from app.core.database import get_db
from app.core.exceptions import Conflict, NotFound
from app.modules.calendar.models import CalendarEvent
from app.modules.calendar.schemas import CalendarEventCreate, CalendarEventOut, CalendarEventUpdate
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/calendar/events", tags=["calendar"])


@router.post("", response_model=CalendarEventOut, status_code=status.HTTP_201_CREATED)
def create_event(
    payload: CalendarEventCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> CalendarEventOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    event = CalendarEvent(
        teacher_id=tid,
        class_id=payload.class_id,
        title=payload.title,
        kind=payload.kind,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        recurrence_rule=payload.recurrence_rule,
        reminder_minutes=payload.reminder_minutes,
        version=1,
    )
    db.add(event)
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="calendar_event_create",
            entity_type="calendar_event",
            entity_id=event.id,
            after={"title": event.title, "kind": event.kind},
        )
    )
    db.commit()
    return event


@router.get("", response_model=list[CalendarEventOut])
def list_events(
    starts_after: datetime | None = Query(default=None),
    ends_before: datetime | None = Query(default=None),
    class_id: uuid.UUID | None = Query(default=None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> list[CalendarEventOut]:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    q = select(CalendarEvent).where(
        CalendarEvent.teacher_id == tid,
        CalendarEvent.deleted_at.is_(None),
    )
    if starts_after:
        q = q.where(CalendarEvent.starts_at >= starts_after)
    if ends_before:
        q = q.where(CalendarEvent.ends_at <= ends_before)
    if class_id:
        q = q.where(CalendarEvent.class_id == class_id)

    q = q.order_by(CalendarEvent.starts_at.asc())
    return list(db.scalars(q).all())


@router.patch("/{event_id}", response_model=CalendarEventOut)
def update_event(
    event_id: uuid.UUID,
    payload: CalendarEventUpdate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> CalendarEventOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    event = db.scalar(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id,
            CalendarEvent.teacher_id == tid,
            CalendarEvent.deleted_at.is_(None),
        )
    )
    if not event:
        raise NotFound("Calendar event not found")

    if event.version != payload.base_version:
        raise Conflict(f"Version conflict: current {event.version} != client {payload.base_version}")

    before = {"title": event.title, "kind": event.kind}
    if payload.title is not None:
        event.title = payload.title
    if payload.kind is not None:
        event.kind = payload.kind
    if payload.starts_at is not None:
        event.starts_at = payload.starts_at
    if payload.ends_at is not None:
        event.ends_at = payload.ends_at
    if payload.recurrence_rule is not None:
        event.recurrence_rule = payload.recurrence_rule
    if payload.reminder_minutes is not None:
        event.reminder_minutes = payload.reminder_minutes

    event.version += 1
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="calendar_event_update",
            entity_type="calendar_event",
            entity_id=event.id,
            before=before,
            after={"title": event.title, "kind": event.kind},
        )
    )
    db.commit()
    return event


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event(
    event_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> None:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    event = db.scalar(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id,
            CalendarEvent.teacher_id == tid,
            CalendarEvent.deleted_at.is_(None),
        )
    )
    if not event:
        raise NotFound("Calendar event not found")

    event.deleted_at = datetime.now(timezone.utc)
    event.version += 1
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="calendar_event_delete",
            entity_type="calendar_event",
            entity_id=event.id,
        )
    )
    db.commit()
