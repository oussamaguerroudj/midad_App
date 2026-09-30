from fastapi.testclient import TestClient

from app.main import create_app


def client() -> TestClient:
    return TestClient(create_app(), raise_server_exceptions=False)


def test_liveness_ok_and_security_headers():
    r = client().get("/api/v1/health")
    assert r.status_code == 200 and r.json() == {"status": "ok"}
    assert r.headers["x-content-type-options"] == "nosniff"


def test_unknown_route_uses_structured_error():
    r = client().get("/api/v1/nope")
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "NOT_FOUND"


def test_no_stack_trace_leaks_on_500():
    from fastapi import FastAPI
    app = create_app()

    @app.get("/boom")
    def boom():
        raise RuntimeError("secret internals")

    r = TestClient(app, raise_server_exceptions=False).get("/boom")
    assert r.status_code == 500
    assert "secret internals" not in r.text
    assert r.json()["error"]["code"] == "INTERNAL_ERROR"
