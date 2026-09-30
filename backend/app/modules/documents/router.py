import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import AppError, Conflict, NotFound
from app.modules.documents.models import Document, DocumentFolder
from app.modules.documents.schemas import (
    DocumentCreate,
    DocumentFolderCreate,
    DocumentFolderOut,
    DocumentOut,
    DocumentUpdate,
)
from app.shared.deps import Principal, current_principal

router = APIRouter(tags=["documents"])


# --- Document Folders ---

@router.get("/document-folders", response_model=list[DocumentFolderOut])
def list_document_folders(
    parent_id: uuid.UUID | None = Query(None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    stmt = select(DocumentFolder).where(
        DocumentFolder.teacher_id == tid,
        DocumentFolder.deleted_at.is_(None),
    )
    if parent_id is not None:
        stmt = stmt.where(DocumentFolder.parent_id == parent_id)
    return db.execute(stmt.order_by(DocumentFolder.name.asc())).scalars().all()


@router.post("/document-folders", response_model=DocumentFolderOut, status_code=201)
def create_document_folder(
    payload: DocumentFolderCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    if payload.parent_id:
        parent = db.execute(
            select(DocumentFolder).where(
                DocumentFolder.id == payload.parent_id,
                DocumentFolder.teacher_id == tid,
                DocumentFolder.deleted_at.is_(None),
            )
        ).scalar_one_or_none()
        if not parent:
            raise NotFound("Parent folder not found.")

    folder = DocumentFolder(
        teacher_id=tid,
        parent_id=payload.parent_id,
        name=payload.name.strip(),
    )
    db.add(folder)
    db.commit()
    db.refresh(folder)
    return folder


@router.delete("/document-folders/{folder_id}", status_code=204)
def delete_document_folder(
    folder_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    folder = db.execute(
        select(DocumentFolder).where(
            DocumentFolder.id == folder_id,
            DocumentFolder.teacher_id == tid,
            DocumentFolder.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not folder:
        raise NotFound("Folder not found.")

    folder.deleted_at = datetime.now(timezone.utc)
    db.commit()
    return None


# --- Documents ---

@router.get("/documents", response_model=list[DocumentOut])
def list_documents(
    folder_id: uuid.UUID | None = Query(None),
    search: str | None = Query(None),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    stmt = select(Document).where(
        Document.teacher_id == tid,
        Document.deleted_at.is_(None),
    )
    if folder_id is not None:
        stmt = stmt.where(Document.folder_id == folder_id)
    if search:
        stmt = stmt.where(Document.file_name.ilike(f"%{search.strip()}%"))

    return db.execute(stmt.order_by(Document.created_at.desc())).scalars().all()


@router.post("/documents", response_model=DocumentOut, status_code=201)
def create_document(
    payload: DocumentCreate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    if payload.folder_id:
        folder = db.execute(
            select(DocumentFolder).where(
                DocumentFolder.id == payload.folder_id,
                DocumentFolder.teacher_id == tid,
                DocumentFolder.deleted_at.is_(None),
            )
        ).scalar_one_or_none()
        if not folder:
            raise NotFound("Folder not found.")

    doc = Document(
        teacher_id=tid,
        folder_id=payload.folder_id,
        file_name=payload.file_name.strip(),
        mime_type=payload.mime_type,
        size_bytes=payload.size_bytes,
        storage_key=payload.storage_key,
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)
    return doc


@router.put("/documents/{doc_id}", response_model=DocumentOut)
def update_document(
    doc_id: uuid.UUID,
    payload: DocumentUpdate,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    doc = db.execute(
        select(Document).where(
            Document.id == doc_id,
            Document.teacher_id == tid,
            Document.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not doc:
        raise NotFound("Document not found.")

    if payload.file_name is not None:
        doc.file_name = payload.file_name.strip()
    if payload.folder_id is not None:
        if payload.folder_id:
            folder = db.execute(
                select(DocumentFolder).where(
                    DocumentFolder.id == payload.folder_id,
                    DocumentFolder.teacher_id == tid,
                    DocumentFolder.deleted_at.is_(None),
                )
            ).scalar_one_or_none()
            if not folder:
                raise NotFound("Folder not found.")
        doc.folder_id = payload.folder_id

    doc.version += 1
    doc.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(doc)
    return doc


@router.delete("/documents/{doc_id}", status_code=204)
def delete_document(
    doc_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    doc = db.execute(
        select(Document).where(
            Document.id == doc_id,
            Document.teacher_id == tid,
            Document.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not doc:
        raise NotFound("Document not found.")

    doc.deleted_at = datetime.now(timezone.utc)
    db.commit()
    return None
