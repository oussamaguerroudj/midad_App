import uuid
from datetime import date, timedelta
from starlette.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_phase2_lessons_journal_assignments_curriculum() -> None:
    # 1. Register teacher
    email = f"teacher_p2_{uuid.uuid4().hex[:8]}@midad.app"
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "Password123!",
            "full_name": "أستاذ المادة",
            "school_name": "ثانوية الشهداء",
            "locale": "ar",
        },
    )
    assert reg_resp.status_code == 200, reg_resp.text
    token = reg_resp.json()["tokens"]["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Create class
    class_resp = client.post(
        "/api/v1/classes",
        headers=headers,
        json={"name": "2 ع ت 1", "level": "الثانية ثانوي", "subject_name": "العلوم الطبيعية"},
    )
    assert class_resp.status_code in (200, 201), class_resp.text
    class_data = class_resp.json()
    class_id = class_data["id"]
    subject_id = class_data["subject_id"]
    academic_year_id = class_data["academic_year_id"]

    # 3. Create students
    s1_resp = client.post(
        "/api/v1/students",
        headers=headers,
        json={"first_name": "حسام", "last_name": "قادري", "class_id": class_id},
    )
    assert s1_resp.status_code in (200, 201), s1_resp.text
    student_id = s1_resp.json()["id"]

    # --- LESSONS & TEACHER JOURNAL ---
    today = date.today()
    lesson_resp = client.post(
        "/api/v1/lessons",
        headers=headers,
        json={
            "topic": "انقسام الخلايا والظواهر الحيوية",
            "class_id": class_id,
            "subject_id": subject_id,
            "academic_year_id": academic_year_id,
            "lesson_date": today.isoformat(),
            "duration_min": 60,
            "objectives": "التعرف على مراحل الانقسام الخيطي المتساوي",
            "content": "مخططات وتجارب بالمجهر الضوئي",
            "completion": "planned",
        },
    )
    assert lesson_resp.status_code == 201, lesson_resp.text
    lesson_data = lesson_resp.json()
    lesson_id = lesson_data["id"]
    assert lesson_data["completion"] == "planned"
    assert lesson_data["version"] == 1

    # Update lesson (Journal Entry: mark completed & record covered content)
    patch_resp = client.patch(
        f"/api/v1/lessons/{lesson_id}",
        headers=headers,
        json={
            "completion": "completed",
            "journal_covered": "تم إنجاز النشاط 1 و2 مع حل التطبيق رقم 3 في الكتاب المدرسي.",
            "base_version": 1,
        },
    )
    assert patch_resp.status_code == 200
    updated_lesson = patch_resp.json()
    assert updated_lesson["completion"] == "completed"
    assert updated_lesson["version"] == 2
    assert "تم إنجاز النشاط" in updated_lesson["journal_covered"]

    # Optimistic locking conflict test
    conflict_resp = client.patch(
        f"/api/v1/lessons/{lesson_id}",
        headers=headers,
        json={"completion": "planned", "base_version": 1},
    )
    assert conflict_resp.status_code == 409

    # List lessons
    list_lessons_resp = client.get(f"/api/v1/lessons?class_id={class_id}", headers=headers)
    assert list_lessons_resp.status_code == 200
    assert len(list_lessons_resp.json()) == 1

    # --- ASSIGNMENTS ---
    due_date = today + timedelta(days=7)
    asg_resp = client.post(
        "/api/v1/assignments",
        headers=headers,
        json={
            "title": "واجب منزلي: تمرين رقم 4 صفحة 45",
            "description": "رسم تخطيطي للمرحلة الاستوائية والانفصالية",
            "class_id": class_id,
            "subject_id": subject_id,
            "academic_year_id": academic_year_id,
            "due_on": due_date.isoformat(),
        },
    )
    assert asg_resp.status_code == 201, asg_resp.text
    assignment_id = asg_resp.json()["id"]

    # Record student assignment status
    record_resp = client.post(
        f"/api/v1/assignments/{assignment_id}/records",
        headers=headers,
        json={"records": [{"student_id": student_id, "status": "completed"}]},
    )
    assert record_resp.status_code == 200
    records = record_resp.json()
    assert len(records) == 1
    assert records[0]["status"] == "completed"

    # Query records
    get_records_resp = client.get(f"/api/v1/assignments/{assignment_id}/records", headers=headers)
    assert get_records_resp.status_code == 200
    assert len(get_records_resp.json()) == 1
    assert get_records_resp.json()[0]["student_name"] == "حسام قادري"

    # --- CURRICULUM ---
    unit_resp = client.post(
        "/api/v1/curriculum/units",
        headers=headers,
        json={
            "subject_id": subject_id,
            "level": "الثانية ثانوي",
            "title": "الوحدة 1: آليات التنظيم العصبي والهرموني",
            "position": 1,
        },
    )
    assert unit_resp.status_code == 201
    unit_id = unit_resp.json()["id"]

    cur_lesson_resp = client.post(
        "/api/v1/curriculum/lessons",
        headers=headers,
        json={
            "unit_id": unit_id,
            "title": "الدرس 1: المنعكس العضلي ودعامته التشريحية",
            "position": 1,
        },
    )
    assert cur_lesson_resp.status_code == 201
    cur_lesson_id = cur_lesson_resp.json()["id"]

    # Update progress for class
    prog_resp = client.post(
        "/api/v1/curriculum/progress",
        headers=headers,
        json={
            "class_id": class_id,
            "curriculum_lesson_id": cur_lesson_id,
            "academic_year_id": academic_year_id,
            "status": "completed",
        },
    )
    assert prog_resp.status_code == 200
    assert prog_resp.json()["status"] == "completed"

    # Fetch curriculum units with progress for this class
    units_query_resp = client.get(
        f"/api/v1/curriculum/units?subject_id={subject_id}&level=الثانية ثانوي&class_id={class_id}",
        headers=headers,
    )
    assert units_query_resp.status_code == 200
    units_list = units_query_resp.json()
    assert len(units_list) == 1
    assert units_list[0]["lessons"][0]["progress_status"] == "completed"
