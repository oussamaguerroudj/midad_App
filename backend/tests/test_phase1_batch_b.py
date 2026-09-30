import uuid
from datetime import date
from starlette.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_attendance_gradebook_and_sync_workflow():
    uid = uuid.uuid4().hex[:8]
    email = f"teacher_b_{uid}@midad.app"

    # 1. Register teacher
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "Password123!",
            "full_name": "الأستاذ كريم",
            "school_name": "متوسطة النجاح",
            "locale": "ar",
        },
    )
    assert reg_resp.status_code == 200, reg_resp.text
    access_token = reg_resp.json()["tokens"]["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    # 2. Create Class and Students
    cls_resp = client.post(
        "/api/v1/classes",
        json={"name": "3 م 1", "level": "الثالثة متوسط", "subject_name": "العلوم الطبيعية"},
        headers=headers,
    )
    assert cls_resp.status_code == 200
    class_id = cls_resp.json()["id"]

    s1_resp = client.post(
        "/api/v1/students",
        json={"first_name": "أيمن", "last_name": "سعدي", "class_id": class_id},
        headers=headers,
    )
    assert s1_resp.status_code == 200
    s1_id = s1_resp.json()["id"]

    s2_resp = client.post(
        "/api/v1/students",
        json={"first_name": "مريم", "last_name": "قاسمي", "class_id": class_id},
        headers=headers,
    )
    assert s2_resp.status_code == 200
    s2_id = s2_resp.json()["id"]

    # 3. Attendance Workflow
    today_str = date.today().isoformat()
    sess_resp = client.post(
        "/api/v1/attendance/sessions",
        json={"class_id": class_id, "session_date": today_str, "slot": "08:00"},
        headers=headers,
    )
    assert sess_resp.status_code == 200
    session_id = sess_resp.json()["id"]

    # Bulk save attendance records
    att_save_resp = client.post(
        f"/api/v1/attendance/sessions/{session_id}/records",
        json={
            "records": [
                {"student_id": s1_id, "status": "present"},
                {"student_id": s2_id, "status": "absent", "note": "غياب مبرر بشهادة طبية"},
            ]
        },
        headers=headers,
    )
    assert att_save_resp.status_code == 200, att_save_resp.text
    records = att_save_resp.json()
    assert len(records) == 2

    # Fetch session details
    detail_resp = client.get(f"/api/v1/attendance/sessions/{session_id}", headers=headers)
    assert detail_resp.status_code == 200
    detail_data = detail_resp.json()
    assert len(detail_data["records"]) == 2
    absent_rec = next(r for r in detail_data["records"] if r["student_id"] == s2_id)
    assert absent_rec["status"] == "absent"
    assert absent_rec["note"] == "غياب مبرر بشهادة طبية"

    # 4. Gradebook Workflow
    asm_resp = client.post(
        "/api/v1/assessments",
        json={
            "class_id": class_id,
            "title": "الفرض الأول للفصل الأول",
            "kind": "test",
            "assessed_on": today_str,
            "max_score": 20.0,
            "coefficient": 2.0,
        },
        headers=headers,
    )
    assert asm_resp.status_code == 200
    asm_id = asm_resp.json()["id"]

    # Bulk enter scores
    grades_resp = client.post(
        f"/api/v1/assessments/{asm_id}/results",
        json={
            "results": [
                {"student_id": s1_id, "score": 17.5, "status": "graded"},
                {"student_id": s2_id, "score": 14.0, "status": "graded"},
            ]
        },
        headers=headers,
    )
    assert grades_resp.status_code == 200
    assert len(grades_resp.json()) == 2
    assert grades_resp.json()[0]["score"] == 17.5

    # Enforce score <= max_score constraint:
    bad_grade_resp = client.post(
        f"/api/v1/assessments/{asm_id}/results",
        json={"results": [{"student_id": s1_id, "score": 25.0, "status": "graded"}]},
        headers=headers,
    )
    assert bad_grade_resp.status_code == 400

    # 5. Sync Engine Workflow
    mut1_id = str(uuid.uuid4())
    sync_resp = client.post(
        "/api/v1/sync",
        json={
            "device_id": "test_device_01",
            "mutations": [
                {
                    "mutation_id": mut1_id,
                    "entity_type": "class",
                    "entity_id": str(uuid.uuid4()),
                    "operation": "CREATE",
                    "base_version": 0,
                    "payload": {
                        "name": "قسم المزامنة الجديد",
                        "level": "الرابعة متوسط",
                        "subject_name": "الرياضيات",
                    },
                }
            ],
        },
        headers=headers,
    )
    assert sync_resp.status_code == 200, sync_resp.text
    outcomes = sync_resp.json()["outcomes"]
    assert len(outcomes) == 1
    assert outcomes[0]["outcome"] == "applied"
    assert outcomes[0]["version"] == 1

    # Test idempotency: replay same mutation_id returns stored outcome
    replay_resp = client.post(
        "/api/v1/sync",
        json={
            "device_id": "test_device_01",
            "mutations": [
                {
                    "mutation_id": mut1_id,
                    "entity_type": "class",
                    "entity_id": str(uuid.uuid4()),
                    "operation": "CREATE",
                    "base_version": 0,
                    "payload": {},
                }
            ],
        },
        headers=headers,
    )
    assert replay_resp.status_code == 200
    replay_outcomes = replay_resp.json()["outcomes"]
    assert replay_outcomes[0]["outcome"] == "applied"
    assert replay_outcomes[0]["version"] == 1

    # Pull changes
    pull_resp = client.get("/api/v1/sync/changes", headers=headers)
    assert pull_resp.status_code == 200
    assert "changes" in pull_resp.json()
    assert len(pull_resp.json()["changes"]) > 0
