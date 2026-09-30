import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.audit_model import AuditLog
from app.core.database import get_db
from app.core.exceptions import Conflict, NotFound
from app.modules.tasks.models import Task
from app.modules.tasks.schemas import TaskCreate, TaskOut, TaskUpdate
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.post("", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def create_task(
    payload: TaskCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> TaskOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    task = Task(
        teacher_id=tid,
        title=payload.title,
        description=payload.description,
        priority=payload.priority,
        due_at=payload.due_at,
        recurrence_rule=payload.recurrence_rule,
        version=1,
    )
    db.add(task)
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="task_create",
            entity_type="task",
            entity_id=task.id,
            after={"title": task.title, "priority": task.priority},
        )
    )
    db.commit()
    return task


@router.get("", response_model=list[TaskOut])
def list_tasks(
    completed: bool | None = Query(default=None),
    priority: str | None = Query(default=None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> list[TaskOut]:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    q = select(Task).where(Task.teacher_id == tid, Task.deleted_at.is_(None))
    if completed is True:
        q = q.where(Task.completed_at.is_not(None))
    elif completed is False:
        q = q.where(Task.completed_at.is_(None))
    if priority:
        q = q.where(Task.priority == priority)

    q = q.order_by(Task.due_at.asc().nulls_last(), Task.created_at.desc())
    return list(db.scalars(q).all())


@router.patch("/{task_id}", response_model=TaskOut)
def update_task(
    task_id: uuid.UUID,
    payload: TaskUpdate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> TaskOut:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    task = db.scalar(
        select(Task).where(
            Task.id == task_id,
            Task.teacher_id == tid,
            Task.deleted_at.is_(None),
        )
    )
    if not task:
        raise NotFound("Task not found")

    if task.version != payload.base_version:
        raise Conflict(f"Version conflict: current {task.version} != client {payload.base_version}")

    before = {"title": task.title, "completed": task.completed_at is not None}
    if payload.title is not None:
        task.title = payload.title
    if payload.description is not None:
        task.description = payload.description
    if payload.priority is not None:
        task.priority = payload.priority
    if payload.due_at is not None:
        task.due_at = payload.due_at
    if payload.completed is not None:
        task.completed_at = datetime.now(timezone.utc) if payload.completed else None

    task.version += 1
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="task_update",
            entity_type="task",
            entity_id=task.id,
            before=before,
            after={"title": task.title, "completed": task.completed_at is not None},
        )
    )
    db.commit()
    return task


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(
    task_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
) -> None:
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    uid = uuid.UUID(principal.user_id)

    task = db.scalar(
        select(Task).where(
            Task.id == task_id,
            Task.teacher_id == tid,
            Task.deleted_at.is_(None),
        )
    )
    if not task:
        raise NotFound("Task not found")

    task.deleted_at = datetime.now(timezone.utc)
    task.version += 1
    db.flush()

    db.add(
        AuditLog(
            teacher_id=tid,
            actor_user_id=uid,
            action="task_delete",
            entity_type="task",
            entity_id=task.id,
        )
    )
    db.commit()
