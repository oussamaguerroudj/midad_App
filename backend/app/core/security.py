"""Password hashing (Argon2id) and JWT helpers.

Access tokens are short-lived and stateless. Refresh tokens carry a `jti`; the auth module
(Phase 1) stores only a SHA-256 hash of each refresh token to support rotation and revocation.
"""
import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from app.core.config import get_settings
from app.core.exceptions import AuthError

_hasher = PasswordHasher()  # argon2id defaults
ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    try:
        return _hasher.verify(hashed, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


def needs_rehash(hashed: str) -> bool:
    return _hasher.check_needs_rehash(hashed)


def _encode(subject: str, kind: str, ttl: timedelta, secret: str, extra: dict | None = None) -> tuple[str, str, datetime]:
    now = datetime.now(timezone.utc)
    jti = uuid.uuid4().hex
    exp = now + ttl
    claims = {"sub": subject, "typ": kind, "jti": jti, "iat": now, "exp": exp, **(extra or {})}
    return jwt.encode(claims, secret, algorithm=ALGORITHM), jti, exp


def create_access_token(user_id: str, extra: dict | None = None) -> str:
    s = get_settings()
    return _encode(user_id, "access", timedelta(minutes=s.access_token_minutes), s.jwt_secret, extra)[0]


def create_refresh_token(user_id: str) -> tuple[str, str, datetime]:
    s = get_settings()
    return _encode(user_id, "refresh", timedelta(days=s.refresh_token_days), s.jwt_refresh_secret)


def decode_token(token: str, expected_type: str) -> dict:
    s = get_settings()
    secret = s.jwt_secret if expected_type == "access" else s.jwt_refresh_secret
    try:
        claims = jwt.decode(token, secret, algorithms=[ALGORITHM], options={"require": ["exp", "sub", "typ", "jti"]})
    except jwt.PyJWTError as exc:
        raise AuthError("Invalid or expired session.") from exc
    if claims.get("typ") != expected_type:
        raise AuthError("Invalid or expired session.")
    return claims


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def new_opaque_token() -> str:
    return secrets.token_urlsafe(32)
