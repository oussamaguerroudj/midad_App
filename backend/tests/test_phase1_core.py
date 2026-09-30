import uuid
import pytest
from starlette.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_auth_and_core_workflow():
    uid = uuid.uuid4().hex[:8]
    email_a = f"teacher_a_{uid}@midad.app"
    email_b = f"teacher_b_{uid}@midad.app"

    # 1. Register Teacher A
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": email_a,
            "password": "Password123!",
            "full_name": "أحمد المنصوري",
            "school_name": "مدرسة الأمل",
            "locale": "ar",
        },
    )
    assert reg_resp.status_code == 200, reg_resp.text
    data_a = reg_resp.json()
    assert "tokens" in data_a
    access_token_a = data_a["tokens"]["access_token"]
    refresh_token_a = data_a["tokens"]["refresh_token"]
    assert data_a["user"]["teacher"] is not None
    assert data_a["user"]["teacher"]["full_name"] == "أحمد المنصوري"

    headers_a = {"Authorization": f"Bearer {access_token_a}"}

    # 2. Get profile /me
    me_resp = client.get("/api/v1/auth/me", headers=headers_a)
    assert me_resp.status_code == 200
    assert me_resp.json()["email"] == email_a

    # 3. Test refresh token rotation
    ref_resp = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token_a},
    )
    assert ref_resp.status_code == 200
    new_access_a = ref_resp.json()["access_token"]
    new_refresh_a = ref_resp.json()["refresh_token"]
    assert new_access_a != access_token_a
    headers_a = {"Authorization": f"Bearer {new_access_a}"}

    # Old refresh token is revoked
    bad_ref_resp = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token_a},
    )
    assert bad_ref_resp.status_code == 401
    assert bad_ref_resp.json()["error"]["code"] == "AUTH_ERROR"

    # 4. Create class for Teacher A
    class_resp = client.post(
        "/api/v1/classes",
        json={
            "name": "القسم 1 ج م ع 1",
            "level": "الأولى ثانوي",
            "subject_name": "الرياضيات",
        },
        headers=headers_a,
    )
    assert class_resp.status_code == 200, class_resp.text
    class_data = class_resp.json()
    class_id = class_data["id"]
    assert class_data["name"] == "القسم 1 ج م ع 1"
    assert class_data["subject_name"] == "الرياضيات"

    # 5. Create student and enroll
    student_resp = client.post(
        "/api/v1/students",
        json={
            "first_name": "ياسين",
            "last_name": "براهيمي",
            "external_ref": "MAT-2026-001",
            "class_id": class_id,
        },
        headers=headers_a,
    )
    assert student_resp.status_code == 200, student_resp.text
    student_data = student_resp.json()
    student_id = student_data["id"]
    assert student_data["first_name"] == "ياسين"

    # 6. Verify class details have enrolled student
    class_detail = client.get(f"/api/v1/classes/{class_id}", headers=headers_a)
    assert class_detail.status_code == 200
    assert class_detail.json()["student_count"] == 1
    assert len(class_detail.json()["students"]) == 1
    assert class_detail.json()["students"][0]["id"] == student_id

    # 7. Add student note
    note_resp = client.post(
        f"/api/v1/students/{student_id}/notes",
        json={"body": "تلميذ متميز ومشارك فعال في حصص حل التمارين."},
        headers=headers_a,
    )
    assert note_resp.status_code == 200
    assert note_resp.json()["body"] == "تلميذ متميز ومشارك فعال في حصص حل التمارين."

    # 8. Multi-tenancy check: Register Teacher B
    reg_b = client.post(
        "/api/v1/auth/register",
        json={
            "email": email_b,
            "password": "Password123!",
            "full_name": "فاطمة الزهراء",
            "school_name": "ثانوية المتنبي",
            "locale": "ar",
        },
    )
    assert reg_b.status_code == 200
    headers_b = {"Authorization": f"Bearer {reg_b.json()['tokens']['access_token']}"}

    # Teacher B tries to access Teacher A's class -> must return 404 (spec §54: foreign id yields 404, never 403)
    b_access_class = client.get(f"/api/v1/classes/{class_id}", headers=headers_b)
    assert b_access_class.status_code == 404
    assert b_access_class.json()["error"]["code"] == "NOT_FOUND"

    # Teacher B tries to access Teacher A's student -> 404
    b_access_student = client.get(f"/api/v1/students/{student_id}", headers=headers_b)
    assert b_access_student.status_code == 404
    assert b_access_student.json()["error"]["code"] == "NOT_FOUND"

    # 9. Optimistic locking check on Class update
    # Current version is 1. If client sends base_version=99, return 409 CONFLICT_ERROR
    conflict_resp = client.patch(
        f"/api/v1/classes/{class_id}",
        json={"name": "القسم المعدل", "base_version": 99},
        headers=headers_a,
    )
    assert conflict_resp.status_code == 409
    assert conflict_resp.json()["error"]["code"] == "CONFLICT_ERROR"
    assert "current_version" in conflict_resp.json()["error"]["details"]
