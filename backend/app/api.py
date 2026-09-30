from fastapi import APIRouter

from app.modules.assessments.router import router as assessments_router
from app.modules.attendance.router import router as attendance_router
from app.modules.auth.router import router as auth_router
from app.modules.classes.router import router as classes_router
from app.modules.health import router as health_router
from app.modules.students.router import router as students_router
from app.modules.sync.router import router as sync_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(classes_router)
api_router.include_router(students_router)
api_router.include_router(attendance_router)
api_router.include_router(assessments_router)
api_router.include_router(sync_router)
