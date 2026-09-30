import pytest

from app.core.exceptions import AuthError
from app.core.security import (create_access_token, create_refresh_token, decode_token, hash_password,
                               verify_password)


def test_password_roundtrip_uses_argon2id():
    h = hash_password("s3cret-pass")
    assert h.startswith("$argon2id$")
    assert verify_password("s3cret-pass", h)
    assert not verify_password("wrong", h)


def test_access_token_roundtrip():
    claims = decode_token(create_access_token("user-1"), "access")
    assert claims["sub"] == "user-1" and claims["typ"] == "access"


def test_refresh_token_cannot_be_used_as_access():
    token, _, _ = create_refresh_token("user-1")
    with pytest.raises(AuthError):
        decode_token(token, "access")


def test_garbage_token_rejected():
    with pytest.raises(AuthError):
        decode_token("not-a-jwt", "access")
