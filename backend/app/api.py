from fastapi import APIRouter

from app.modules.health import router as health_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(health_router)
# Phase 1 adds: auth, users(/me), classes, students, attendance, grades, sync.
