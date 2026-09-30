"""Authorization building blocks. Phase 1 wires these into every module.

Rule (spec §54/§84): the backend never trusts the client. Every query on teacher-owned data
must be scoped by `principal.teacher_id`; a foreign id yields 404, never 403, so ids cannot be probed.
"""
from dataclasses import dataclass

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.exceptions import AuthError
from app.core.security import decode_token

_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class Principal:
    user_id: str
    teacher_id: str | None = None
    school_id: str | None = None


def current_principal(cred: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> Principal:
    if cred is None:
        raise AuthError("Authentication required.")
    claims = decode_token(cred.credentials, "access")
    return Principal(user_id=claims["sub"], teacher_id=claims.get("tid"), school_id=claims.get("sid"))
