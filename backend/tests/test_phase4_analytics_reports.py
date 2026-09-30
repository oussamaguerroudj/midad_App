import uuid
from starlette.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_phase4_analytics_and_reports_suite() -> None:
    # 1. Register teacher
    email = f"teacher_p4_{uuid.uuid4().hex[:8]}@midad.app"
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "Password123!",
            "full_name": "أستاذ التحليلات والتقارير",
            "school_name": "ثانوية الشهداء",
            "locale": "ar",
        },
    )
    assert reg_resp.status_code == 200, reg_resp.text
    token = reg_resp.json()["tokens"]["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Academic Year
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

    # 3. Create Class
    class_resp = client.post(
        "/api/v1/classes",
        headers=headers,
        json={
            "name": "3 AS Math 1",
            "subject_name": "الرياضيات",
            "academic_year_id": ay_id,
            "level": "3AS",
        },
    )
    assert class_resp.status_code in [200, 201], class_resp.text
    class_id = class_resp.json()["id"]

    # 4. Import students via CSV endpoint
    csv_content = """رقم_التسجيل,اللقب,الاسم
2026-001,بن علي,سارة
2026-002,قاسمي,أحمد
2026-003,منصوري,فاطمة
"""
    import_resp = client.post(
        f"/api/v1/reports/import/students/{class_id}",
        headers=headers,
        json={"csv_content": csv_content},
    )
    assert import_resp.status_code == 200, import_resp.text
    import_data = import_resp.json()
    assert import_data["total_created"] == 3
    assert import_data["total_skipped"] == 0

    # Also test JSON rows import
    import_json_resp = client.post(
        f"/api/v1/reports/import/students/{class_id}",
        headers=headers,
        json={
            "rows": [
                {"first_name": "يوسف", "last_name": "رحماني", "registration_number": "2026-004"}
            ]
        },
    )
    assert import_json_resp.status_code == 200, import_json_resp.text
    assert import_json_resp.json()["total_created"] == 1

    # Fetch students list in class
    st_list_resp = client.get(f"/api/v1/students?class_id={class_id}", headers=headers)
    assert st_list_resp.status_code == 200
    students = st_list_resp.json()
    assert len(students) >= 4
    s1 = next(s for s in students if s["last_name"] == "بن علي")
    s2 = next(s for s in students if s["last_name"] == "قاسمي")
    s3 = next(s for s in students if s["last_name"] == "منصوري")

    # 5. Create Attendance Session and Records
    session_resp = client.post(
        "/api/v1/attendance/sessions",
        headers=headers,
        json={
            "class_id": class_id,
            "session_date": "2026-10-01",
            "starts_at": "08:00:00",
            "ends_at": "09:00:00",
            "room": "قاعة 12",
        },
    )
    assert session_resp.status_code in [200, 201], session_resp.text
    sess_id = session_resp.json()["id"]

    rec_resp = client.post(
        f"/api/v1/attendance/sessions/{sess_id}/records",
        headers=headers,
        json={
            "records": [
                {"student_id": s1["id"], "status": "present"},
                {"student_id": s2["id"], "status": "late", "notes": "تأخر 10 دقائق"},
                {"student_id": s3["id"], "status": "absent", "notes": "غياب غير مبرر"},
            ]
        },
    )
    assert rec_resp.status_code in [200, 201], rec_resp.text

    # 6. Create Assessments and Results
    ass1_resp = client.post(
        "/api/v1/assessments",
        headers=headers,
        json={
            "class_id": class_id,
            "title": "فرض الثلاثي الأول",
            "kind": "test",
            "assessed_on": "2026-10-15",
            "max_score": 20.0,
            "coefficient": 1.0,
        },
    )
    assert ass1_resp.status_code in [200, 201], ass1_resp.text
    ass1_id = ass1_resp.json()["id"]

    ass2_resp = client.post(
        "/api/v1/assessments",
        headers=headers,
        json={
            "class_id": class_id,
            "title": "اختبار الثلاثي الأول",
            "kind": "exam",
            "assessed_on": "2026-11-20",
            "max_score": 20.0,
            "coefficient": 2.0,
        },
    )
    assert ass2_resp.status_code in [200, 201], ass2_resp.text
    ass2_id = ass2_resp.json()["id"]

    # Record scores:
    # S1 (سارة): 18/20, 17/20 (Top student)
    # S2 (أحمد): 12/20, 11/20 (Average student)
    # S3 (فاطمة): 7/20, 8/20 (At-risk student)
    save_res_resp = client.post(
        f"/api/v1/assessments/{ass1_id}/results",
        headers=headers,
        json={
            "results": [
                {"student_id": s1["id"], "score": 18.0},
                {"student_id": s2["id"], "score": 12.0},
                {"student_id": s3["id"], "score": 7.0},
            ]
        },
    )
    assert save_res_resp.status_code in [200, 201], save_res_resp.text

    save_res2_resp = client.post(
        f"/api/v1/assessments/{ass2_id}/results",
        headers=headers,
        json={
            "results": [
                {"student_id": s1["id"], "score": 17.0},
                {"student_id": s2["id"], "score": 11.0},
                {"student_id": s3["id"], "score": 8.0},
            ]
        },
    )
    assert save_res2_resp.status_code in [200, 201], save_res2_resp.text

    # 7. Test Analytics Overview
    overview_resp = client.get("/api/v1/analytics/overview", headers=headers)
    assert overview_resp.status_code == 200, overview_resp.text
    ov = overview_resp.json()
    assert ov["total_students"] >= 4
    assert ov["total_classes"] >= 1
    assert ov["total_assessments"] >= 2
    assert ov["overall_average_score"] > 0
    assert len(ov["class_summaries"]) >= 1

    # 8. Test Class Analytics
    c_analytics_resp = client.get(f"/api/v1/analytics/classes/{class_id}", headers=headers)
    assert c_analytics_resp.status_code == 200, c_analytics_resp.text
    ca = c_analytics_resp.json()
    assert ca["class_id"] == class_id
    assert ca["average_score"] > 0
    assert len(ca["grade_distribution"]) == 5
    assert len(ca["top_students"]) >= 1
    assert ca["top_students"][0]["student_id"] == s1["id"]
    assert len(ca["assessment_trends"]) == 2

    # 9. Test Student Analytics
    s1_analytics_resp = client.get(f"/api/v1/analytics/students/{s1['id']}", headers=headers)
    assert s1_analytics_resp.status_code == 200, s1_analytics_resp.text
    sa1 = s1_analytics_resp.json()
    assert sa1["student_id"] == s1["id"]
    assert sa1["average_score"] >= 17.0
    assert sa1["rank_in_class"] == 1
    assert len(sa1["strengths"]) > 0

    s3_analytics_resp = client.get(f"/api/v1/analytics/students/{s3['id']}", headers=headers)
    assert s3_analytics_resp.status_code == 200, s3_analytics_resp.text
    sa3 = s3_analytics_resp.json()
    assert sa3["student_id"] == s3["id"]
    assert sa3["average_score"] < 10.0
    assert len(sa3["areas_for_growth"]) > 0

    # 10. Test Official Student Bulletin (كشف النقاط)
    bulletin_resp = client.get(f"/api/v1/reports/bulletin/{class_id}/{s1['id']}?term=الفصل الأول", headers=headers)
    assert bulletin_resp.status_code == 200, bulletin_resp.text
    bulletin = bulletin_resp.json()
    assert bulletin["student_id"] == s1["id"]
    assert bulletin["general_average"] >= 17.0
    assert bulletin["honor_roll"] == "امتياز"
    assert len(bulletin["grades"]) == 2
    assert bulletin["rank_in_class"] == 1

    # 11. Test CSV Export of Students
    exp_st_resp = client.get(f"/api/v1/reports/export/students-csv/{class_id}", headers=headers)
    assert exp_st_resp.status_code == 200
    assert "text/csv" in exp_st_resp.headers["content-type"]
    assert "بن علي" in exp_st_resp.text

    # 12. Test CSV Export of Grades
    exp_gr_resp = client.get(f"/api/v1/reports/export/grades-csv/{class_id}", headers=headers)
    assert exp_gr_resp.status_code == 200
    assert "text/csv" in exp_gr_resp.headers["content-type"]
    assert "اختبار الثلاثي الأول" in exp_gr_resp.text
    assert "18.00" in exp_gr_resp.text or "18" in exp_gr_resp.text
