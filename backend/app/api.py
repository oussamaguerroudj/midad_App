from fastapi import APIRouter

from app.modules.auth.router import router as auth_router
from app.modules.classes.router import router as classes_router
from app.modules.health import router as health_router
from app.modules.students.router import router as students_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(classes_router)
api_router.include_router(students_router)
