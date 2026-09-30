import uuid
from starlette.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_phase3_organization_suite() -> None:
    # 1. Register teacher
    email = f"teacher_p3_{uuid.uuid4().hex[:8]}@midad.app"
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "Password123!",
            "full_name": "أستاذ التنظيم والتوثيق",
            "school_name": "ثانوية المتفوقين",
            "locale": "ar",
        },
    )
    assert reg_resp.status_code == 200, reg_resp.text
    token = reg_resp.json()["tokens"]["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Academic Years
    ay_resp = client.post(
        "/api/v1/academic-years",
        headers=headers,
        json={
            "label": f"2026-2027-{uuid.uuid4().hex[:4]}",
            "starts_on": "2026-09-01",
            "ends_on": "2027-06-30",
            "is_current": True,
        },
    )
    assert ay_resp.status_code == 201, ay_resp.text
    ay_id = ay_resp.json()["id"]

    curr_ay = client.get("/api/v1/academic-years/current", headers=headers)
    assert curr_ay.status_code == 200
    assert curr_ay.json()["id"] == ay_id

    # 3. Create Class & Students
    class_resp = client.post(
        "/api/v1/classes",
        headers=headers,
        json={
            "name": "1 AS Sciences 2",
            "subject_name": "العلوم الفيزيائية",
            "academic_year_id": ay_id,
            "level": "1AS",
        },
    )
    assert class_resp.status_code in [200, 201], class_resp.text
    class_id = class_resp.json()["id"]

    st1_resp = client.post(
        "/api/v1/students",
        headers=headers,
        json={"first_name": "وليد", "last_name": "حميدي", "class_id": class_id},
    )
    assert st1_resp.status_code in [200, 201], st1_resp.text
    st1_id = st1_resp.json()["id"]

    st2_resp = client.post(
        "/api/v1/students",
        headers=headers,
        json={"first_name": "أمينة", "last_name": "بن سالم", "class_id": class_id},
    )
    assert st2_resp.status_code in [200, 201], st2_resp.text
    st2_id = st2_resp.json()["id"]

    # 4. Documents & Folders
    f_resp = client.post(
        "/api/v1/document-folders",
        headers=headers,
        json={"name": "الامتحانات والملخصات"},
    )
    assert f_resp.status_code == 201
    folder_id = f_resp.json()["id"]

    doc_resp = client.post(
        "/api/v1/documents",
        headers=headers,
        json={
            "folder_id": folder_id,
            "file_name": "physique_cours_1.pdf",
            "mime_type": "application/pdf",
            "size_bytes": 1048576,
            "storage_key": f"docs/{uuid.uuid4().hex}/cours.pdf",
        },
    )
    assert doc_resp.status_code == 201
    doc_id = doc_resp.json()["id"]

    # Search document
    doc_list = client.get("/api/v1/documents?search=physique", headers=headers)
    assert doc_list.status_code == 200
    assert len(doc_list.json()) == 1

    # 5. Seating Plans
    seat_resp = client.post(
        f"/api/v1/classes/{class_id}/seating-plans",
        headers=headers,
        json={
            "class_id": class_id,
            "name": "مخطط الصفوف الافتراضي",
            "layout": "rows",
            "members": [
                {"student_id": st1_id, "seat_x": 1.0, "seat_y": 1.0},
                {"student_id": st2_id, "seat_x": 2.0, "seat_y": 1.0},
            ],
        },
    )
    assert seat_resp.status_code == 201, seat_resp.text
    assert len(seat_resp.json()["members"]) == 2

    seat_list = client.get(f"/api/v1/classes/{class_id}/seating-plans", headers=headers)
    assert seat_list.status_code == 200
    assert len(seat_list.json()) == 1

    # 6. Student Groups
    group_resp = client.post(
        f"/api/v1/classes/{class_id}/groups",
        headers=headers,
        json={
            "class_id": class_id,
            "name": "فوج التجارب المخبرية أ",
            "student_ids": [st1_id, st2_id],
        },
    )
    assert group_resp.status_code == 201, group_resp.text
    assert len(group_resp.json()["members"]) == 2

    group_list = client.get(f"/api/v1/classes/{class_id}/groups", headers=headers)
    assert group_list.status_code == 200
    assert len(group_list.json()) == 1

    # 7. Student Activity / Participation Log
    act_resp = client.post(
        f"/api/v1/classes/{class_id}/activity-logs",
        headers=headers,
        json={
            "class_id": class_id,
            "student_id": st1_id,
            "category": "positive_contribution",
            "note": "مشاركة ممتازة في حل التمرين",
        },
    )
    assert act_resp.status_code == 201, act_resp.text
    assert act_resp.json()["category"] == "positive_contribution"

    act_list = client.get(f"/api/v1/classes/{class_id}/activity-logs", headers=headers)
    assert act_list.status_code == 200
    assert len(act_list.json()) == 1

    # 8. Activity History
    hist_resp = client.get("/api/v1/activity-history", headers=headers)
    assert hist_resp.status_code == 200
    assert isinstance(hist_resp.json(), list)

    # 9. Follow-up Alerts
    alerts_resp = client.get("/api/v1/follow-up-alerts", headers=headers)
    assert alerts_resp.status_code == 200
    assert isinstance(alerts_resp.json(), list)

    # 10. Global Search
    search_resp = client.get("/api/v1/search?q=وليد", headers=headers)
    assert search_resp.status_code == 200
    search_data = search_resp.json()
    assert search_data["total"] >= 1
    assert any(item["type"] == "student" for item in search_data["results"])
