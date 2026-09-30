"""Structured error contract shared with the mobile app (spec §61).

Every error response has the shape:
  {"error": {"code": "<ErrorCode>", "message": "<safe text>", "details": {...}}}
Stack traces, SQL and secrets are never returned.
"""
import logging
from enum import Enum

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

log = logging.getLogger("midad.errors")


class ErrorCode(str, Enum):
    NETWORK_ERROR = "NETWORK_ERROR"
    AUTH_ERROR = "AUTH_ERROR"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    CONFLICT_ERROR = "CONFLICT_ERROR"
    PERMISSION_ERROR = "PERMISSION_ERROR"
    NOT_FOUND = "NOT_FOUND"
    RATE_LIMITED = "RATE_LIMITED"
    FILE_ERROR = "FILE_ERROR"
    INTERNAL_ERROR = "INTERNAL_ERROR"


class AppError(Exception):
    status_code = 400
    code = ErrorCode.VALIDATION_ERROR

    def __init__(self, message: str, *, details: dict | None = None):
        super().__init__(message)
        self.message = message
        self.details = details or {}


class AuthError(AppError):
    status_code, code = 401, ErrorCode.AUTH_ERROR


class PermissionDenied(AppError):
    status_code, code = 403, ErrorCode.PERMISSION_ERROR


class NotFound(AppError):
    # Also used when a resource exists but belongs to another teacher, so ids cannot be probed.
    status_code, code = 404, ErrorCode.NOT_FOUND


class Conflict(AppError):
    """Stale version. `details` carries the current server version so the client can resolve."""
    status_code, code = 409, ErrorCode.CONFLICT_ERROR


class FileRejected(AppError):
    status_code, code = 422, ErrorCode.FILE_ERROR


def _body(code: ErrorCode, message: str, details: dict | None = None) -> dict:
    return {"error": {"code": code.value, "message": message, "details": details or {}}}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError):
        return JSONResponse(_body(exc.code, exc.message, exc.details), status_code=exc.status_code)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError):
        fields = [{"loc": list(e["loc"]), "type": e["type"]} for e in exc.errors()]
        return JSONResponse(_body(ErrorCode.VALIDATION_ERROR, "Invalid request.", {"fields": fields}),
                            status_code=422)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException):
        code = {401: ErrorCode.AUTH_ERROR, 403: ErrorCode.PERMISSION_ERROR,
                404: ErrorCode.NOT_FOUND, 429: ErrorCode.RATE_LIMITED}.get(exc.status_code, ErrorCode.INTERNAL_ERROR)
        return JSONResponse(_body(code, "Request could not be completed."), status_code=exc.status_code)

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception):
        log.error("unhandled exception", exc_info=exc, extra={"path": request.url.path})
        return JSONResponse(_body(ErrorCode.INTERNAL_ERROR, "Something went wrong."), status_code=500)
