import csv
import io
import uuid
from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.core.audit_model import AuditLog
from app.core.database import get_db
from app.core.exceptions import AppError, NotFound
from app.modules.academic_years.models import AcademicYear

from app.modules.assessments.models import Assessment, AssessmentResult
from app.modules.attendance.models import AttendanceRecord, AttendanceSession
from app.modules.classes.models import SchoolClass
from app.modules.documents.models import Document
from app.modules.lessons.models import Lesson
from app.modules.reports.schemas import (
    AuditLogOut,
    BulletinGradeItem,
    FollowUpAlertOut,
    ImportRosterRequest,
    ImportRosterResponse,
    ImportRosterRow,
    SearchItem,
    SearchResultsOut,
    StudentBulletinOut,
)
from app.modules.schools.models import School
from app.modules.students.models import ClassStudent, Student
from app.modules.tasks.models import Task
from app.modules.users.models import Teacher
from app.shared.deps import Principal, current_principal

router = APIRouter(tags=["reports"])



# --- Activity History ---

@router.get("/activity-history", response_model=list[AuditLogOut])
def get_activity_history(
    entity_type: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    stmt = select(AuditLog).where(AuditLog.teacher_id == tid)
    if entity_type:
        stmt = stmt.where(AuditLog.entity_type == entity_type)

    stmt = stmt.order_by(AuditLog.occurred_at.desc()).limit(limit).offset(offset)
    return db.execute(stmt).scalars().all()


# --- Follow-Up Rules & Alerts ---

@router.get("/follow-up-alerts", response_model=list[FollowUpAlertOut])
def get_follow_up_alerts(
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    """Evaluates automatic follow-up rules across active classes:
    - Rule 1 (Attendance): 3 or more absences in attendance records.
    - Rule 2 (Academic): Assessment average under 10/20.
    """
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    alerts: list[FollowUpAlertOut] = []

    # 1. Attendance Rule: count unexcused / absent status per student per class
    att_stmt = (
        select(
            Student.id,
            Student.first_name,
            Student.last_name,
            SchoolClass.id,
            SchoolClass.name,
            func.count(AttendanceRecord.id).label("absent_count"),
        )
        .join(AttendanceRecord, AttendanceRecord.student_id == Student.id)
        .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
        .join(SchoolClass, SchoolClass.id == AttendanceSession.class_id)
        .where(
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
            SchoolClass.deleted_at.is_(None),
            AttendanceRecord.deleted_at.is_(None),
            AttendanceRecord.status.in_(["absent", "late"]),
        )
        .group_by(Student.id, Student.first_name, Student.last_name, SchoolClass.id, SchoolClass.name)
        .having(func.count(AttendanceRecord.id) >= 3)
    )
    att_results = db.execute(att_stmt).all()
    for row in att_results:
        s_id, s_first, s_last, c_id, c_name, count = row
        alerts.append(
            FollowUpAlertOut(
                id=f"att-{s_id}-{c_id}",
                rule_type="attendance",
                severity="danger" if count >= 5 else "warning",
                student_id=s_id,
                student_name=f"{s_first} {s_last}",
                class_id=c_id,
                class_name=c_name,
                message=f"تنبيه غياب: {count} تسجيلات غياب/تأخر مسجلة لهذا التلميذ في {c_name}.",
                metric_value=count,
            )
        )

    # 2. Academic Rule: average score < 10 for students with at least 1 graded assessment
    grade_stmt = (
        select(
            Student.id,
            Student.first_name,
            Student.last_name,
            SchoolClass.id,
            SchoolClass.name,
            func.avg(AssessmentResult.score).label("avg_score"),
        )
        .join(AssessmentResult, AssessmentResult.student_id == Student.id)
        .join(Assessment, Assessment.id == AssessmentResult.assessment_id)
        .join(SchoolClass, SchoolClass.id == Assessment.class_id)
        .where(
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
            AssessmentResult.deleted_at.is_(None),
            AssessmentResult.score.is_not(None),
        )
        .group_by(Student.id, Student.first_name, Student.last_name, SchoolClass.id, SchoolClass.name)
        .having(func.avg(AssessmentResult.score) < 10.0)
    )
    grade_results = db.execute(grade_stmt).all()
    for row in grade_results:
        s_id, s_first, s_last, c_id, c_name, avg_sc = row
        val = round(float(avg_sc), 2)
        alerts.append(
            FollowUpAlertOut(
                id=f"acad-{s_id}-{c_id}",
                rule_type="academic",
                severity="warning",
                student_id=s_id,
                student_name=f"{s_first} {s_last}",
                class_id=c_id,
                class_name=c_name,
                message=f"متابعة تحصيلية: معدل التقييمات {val}/20 يقل عن عتبة التمكّن في {c_name}.",
                metric_value=val,
            )
        )

    return alerts


# --- Global Search ---

@router.get("/search", response_model=SearchResultsOut)
def global_search(
    q: str = Query(..., min_length=1),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)
    term = f"%{q.strip()}%"

    results: list[SearchItem] = []

    # Classes
    classes = db.execute(
        select(SchoolClass).where(
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
            SchoolClass.name.ilike(term),
        ).limit(5)
    ).scalars().all()
    for c in classes:
        results.append(SearchItem(id=c.id, type="class", title=c.name, subtitle=c.level or "قسم"))

    # Students
    students = db.execute(
        select(Student).where(
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
            or_(Student.first_name.ilike(term), Student.last_name.ilike(term)),
        ).limit(10)
    ).scalars().all()
    for s in students:
        results.append(SearchItem(id=s.id, type="student", title=f"{s.first_name} {s.last_name}", subtitle=s.external_ref or "تلميذ"))

    # Lessons
    lessons = db.execute(
        select(Lesson).where(
            Lesson.teacher_id == tid,
            Lesson.deleted_at.is_(None),
            Lesson.topic.ilike(term),
        ).limit(5)
    ).scalars().all()
    for l in lessons:
        results.append(SearchItem(id=l.id, type="lesson", title=l.topic, subtitle="مذكرة درس"))

    # Documents
    docs = db.execute(
        select(Document).where(
            Document.teacher_id == tid,
            Document.deleted_at.is_(None),
            Document.file_name.ilike(term),
        ).limit(5)
    ).scalars().all()
    for d in docs:
        results.append(SearchItem(id=d.id, type="document", title=d.file_name, subtitle=f"{round(d.size_bytes/1024, 1)} KB"))

    # Tasks
    tasks = db.execute(
        select(Task).where(
            Task.teacher_id == tid,
            Task.deleted_at.is_(None),
            Task.title.ilike(term),
        ).limit(5)
    ).scalars().all()
    for t in tasks:
        results.append(SearchItem(id=t.id, type="task", title=t.title, subtitle="مهمة"))

    return SearchResultsOut(
        query=q,
        total=len(results),
        results=results,
    )


# --- Official Student Bulletin (كشف النقاط الفصلي) ---

@router.get("/reports/bulletin/{class_id}/{student_id}", response_model=StudentBulletinOut)
def get_student_bulletin(

    class_id: uuid.UUID,
    student_id: uuid.UUID,
    term: str = Query("الفصل الأول"),
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    # Teacher & School
    teacher = db.execute(select(Teacher).where(Teacher.id == tid)).scalar_one_or_none()
    teacher_name = teacher.full_name if teacher else "الأستاذ"
    school_name = "المدرسة"
    if teacher and teacher.school_id:
        school = db.execute(select(School).where(School.id == teacher.school_id)).scalar_one_or_none()
        if school:
            school_name = school.name

    # Current academic year
    ay = db.execute(
        select(AcademicYear).where(
            AcademicYear.teacher_id == tid,
            AcademicYear.is_current.is_(True),
            AcademicYear.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    ay_label = ay.label if ay else "2026-2027"

    # Class
    school_class = db.execute(
        select(SchoolClass).where(
            SchoolClass.id == class_id,
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not school_class:
        raise NotFound(f"Class '{class_id}' not found.")

    # Student
    student = db.execute(
        select(Student).where(
            Student.id == student_id,
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not student:
        raise NotFound(f"Student '{student_id}' not found.")

    # Class students
    class_students = db.execute(
        select(Student.id)
        .join(ClassStudent, ClassStudent.student_id == Student.id)
        .where(
            ClassStudent.class_id == class_id,
            ClassStudent.deleted_at.is_(None),
            Student.deleted_at.is_(None),
        )
    ).scalars().all()

    # Assessments in this class
    assessments = db.execute(
        select(Assessment).where(
            Assessment.class_id == class_id,
            Assessment.deleted_at.is_(None),
        ).order_by(Assessment.assessed_on.asc())
    ).scalars().all()

    # Student's results
    bulletin_grades: list[BulletinGradeItem] = []
    total_coef = 0.0
    weighted_sum = 0.0

    # Peer results for ranking & class stats
    peer_averages_map: dict[uuid.UUID, list[float]] = {sid: [] for sid in class_students}

    for a in assessments:
        coef = float(a.coefficient) if a.coefficient and float(a.coefficient) > 0 else 1.0
        results = db.execute(
            select(AssessmentResult).where(
                AssessmentResult.assessment_id == a.id,
                AssessmentResult.deleted_at.is_(None),
                AssessmentResult.score.is_not(None),
            )
        ).scalars().all()

        my_res = None
        for r in results:
            if a.max_score and float(a.max_score) > 0 and r.score is not None:
                norm = (float(r.score) / float(a.max_score)) * 20.0
                if r.student_id in peer_averages_map:
                    peer_averages_map[r.student_id].append(norm)
                if r.student_id == student_id:
                    my_res = r

        if my_res:
            norm_20 = (float(my_res.score) / float(a.max_score)) * 20.0 if a.max_score else 0.0
            bulletin_grades.append(
                BulletinGradeItem(
                    assessment_id=a.id,
                    title=a.title,
                    kind=a.kind,
                    date=str(a.assessed_on) if a.assessed_on else None,
                    coefficient=coef,
                    score=float(my_res.score),
                    max_score=float(a.max_score),
                    normalized_20=round(norm_20, 2),
                )
            )
            weighted_sum += norm_20 * coef
            total_coef += coef

    general_average = round(weighted_sum / total_coef, 2) if total_coef > 0 else 0.0

    # Class stats
    peer_final_avgs = []
    for sid, scs in peer_averages_map.items():
        avg = (sum(scs) / len(scs)) if scs else 0.0
        peer_final_avgs.append((sid, avg))

    peer_final_avgs.sort(key=lambda x: x[1], reverse=True)
    my_rank = 1
    for idx, (sid, _) in enumerate(peer_final_avgs, start=1):
        if sid == student_id:
            my_rank = idx
            break

    scores_only = [p[1] for p in peer_final_avgs]
    highest_avg = round(max(scores_only), 2) if scores_only else 0.0
    lowest_avg = round(min(scores_only), 2) if scores_only else 0.0
    class_overall_avg = round(sum(scores_only) / len(scores_only), 2) if scores_only else 0.0

    # Attendance
    att_records = db.execute(
        select(AttendanceRecord).where(
            AttendanceRecord.student_id == student_id,
            AttendanceRecord.deleted_at.is_(None),
        )
    ).scalars().all()
    absences = sum(1 for r in att_records if r.status == "absent")
    latenesses = sum(1 for r in att_records if r.status == "late")

    # Honor roll & appreciation
    if general_average >= 17.0:
        honor = "امتياز"
        appreciation = "نتائج ممتازة جداً وسلوك مثالي. تهانينا ومزيداً من التألق."
    elif general_average >= 15.0:
        honor = "تهنئة"
        appreciation = "عمل متميز وجاد، واصل على هذا النسق الإيجابي."
    elif general_average >= 13.0:
        honor = "لوحة شرف"
        appreciation = "نتائج حسنة ومجهود طيب، باستطاعتك تحقيق الأفضل."
    elif general_average >= 10.0:
        honor = "تشجيع"
        appreciation = "مستوى متوسط ومقبول، يتطلب مضاعفة الجهد والتركيز المستمر."
    else:
        honor = "إنذار وتنبيه"
        appreciation = "نتائج دون العتبة المطلوبة، يجب التدارك العاجل والالتزام بالمراجعة اليومية."

    return StudentBulletinOut(
        school_name=school_name,
        teacher_name=teacher_name,
        academic_year=ay_label,
        class_id=class_id,
        class_name=school_class.name,
        term=term,
        student_id=student.id,
        student_name=f"{student.first_name} {student.last_name}",
        registration_number=student.external_ref,
        birth_date=None,
        grades=bulletin_grades,
        total_coefficient=total_coef,
        weighted_sum=round(weighted_sum, 2),
        general_average=general_average,
        rank_in_class=my_rank,
        total_students=len(class_students),
        class_highest_average=highest_avg,
        class_lowest_average=lowest_avg,
        class_overall_average=class_overall_avg,
        absences_count=absences,
        lateness_count=latenesses,
        honor_roll=honor,
        teacher_appreciation=appreciation,
    )


# --- Data Import / Export (CSV) ---

@router.get("/export/students-csv/{class_id}")
def export_students_csv(
    class_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    school_class = db.execute(
        select(SchoolClass).where(
            SchoolClass.id == class_id,
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not school_class:
        raise NotFound(f"Class '{class_id}' not found.")

    students = db.execute(
        select(Student)
        .join(ClassStudent, ClassStudent.student_id == Student.id)
        .where(
            ClassStudent.class_id == class_id,
            ClassStudent.deleted_at.is_(None),
            Student.deleted_at.is_(None),
        )
        .order_by(Student.last_name, Student.first_name)
    ).scalars().all()

    output = io.StringIO()
    # UTF-8 BOM for Microsoft Excel on Arabic Windows
    output.write("\ufeff")
    writer = csv.writer(output)
    writer.writerow(["الرقم", "رقم_التسجيل", "اللقب", "الاسم", "عدد_الغيابات", "المعدل"])

    for idx, s in enumerate(students, start=1):
        # Absences
        abs_count = db.execute(
            select(func.count(AttendanceRecord.id)).where(
                AttendanceRecord.student_id == s.id,
                AttendanceRecord.status == "absent",
                AttendanceRecord.deleted_at.is_(None),
            )
        ).scalar_one()

        # Average
        scores = db.execute(
            select(AssessmentResult.score, Assessment.max_score)
            .join(Assessment, Assessment.id == AssessmentResult.assessment_id)
            .where(
                Assessment.class_id == class_id,
                AssessmentResult.student_id == s.id,
                AssessmentResult.deleted_at.is_(None),
                AssessmentResult.score.is_not(None),
            )
        ).all()
        norms = [(float(sc) / float(mx)) * 20.0 for sc, mx in scores if mx and float(mx) > 0 and sc is not None]
        avg_str = f"{round(sum(norms) / len(norms), 2):.2f}" if norms else "-"

        writer.writerow([idx, s.external_ref or "", s.last_name, s.first_name, abs_count, avg_str])

    csv_data = output.getvalue()
    return Response(
        content=csv_data,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="students_{school_class.name}.csv"'},
    )


@router.get("/reports/export/students-csv/{class_id}")
def export_students_csv(
    class_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    school_class = db.execute(
        select(SchoolClass).where(
            SchoolClass.id == class_id,
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not school_class:
        raise NotFound(f"Class '{class_id}' not found.")

    students = db.execute(
        select(Student)
        .join(ClassStudent, ClassStudent.student_id == Student.id)
        .where(
            ClassStudent.class_id == class_id,
            ClassStudent.deleted_at.is_(None),
            Student.deleted_at.is_(None),
        )
        .order_by(Student.last_name, Student.first_name)
    ).scalars().all()

    output = io.StringIO()
    # UTF-8 BOM for Microsoft Excel on Arabic Windows
    output.write("\ufeff")
    writer = csv.writer(output)
    writer.writerow(["الرقم", "رقم_التسجيل", "اللقب", "الاسم", "عدد_الغيابات", "المعدل"])

    for idx, s in enumerate(students, start=1):
        # Absences
        abs_count = db.execute(
            select(func.count(AttendanceRecord.id)).where(
                AttendanceRecord.student_id == s.id,
                AttendanceRecord.status == "absent",
                AttendanceRecord.deleted_at.is_(None),
            )
        ).scalar_one()

        # Average
        scores = db.execute(
            select(AssessmentResult.score, Assessment.max_score)
            .join(Assessment, Assessment.id == AssessmentResult.assessment_id)
            .where(
                Assessment.class_id == class_id,
                AssessmentResult.student_id == s.id,
                AssessmentResult.deleted_at.is_(None),
                AssessmentResult.score.is_not(None),
            )
        ).all()
        norms = [(float(sc) / float(mx)) * 20.0 for sc, mx in scores if mx and float(mx) > 0 and sc is not None]
        avg_str = f"{round(sum(norms) / len(norms), 2):.2f}" if norms else "-"

        writer.writerow([idx, s.external_ref or "", s.last_name, s.first_name, abs_count, avg_str])

    csv_data = output.getvalue()
    return Response(
        content=csv_data,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="students_{school_class.name}.csv"'},
    )


@router.get("/reports/export/grades-csv/{class_id}")
def export_grades_csv(
    class_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    school_class = db.execute(
        select(SchoolClass).where(
            SchoolClass.id == class_id,
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not school_class:
        raise NotFound(f"Class '{class_id}' not found.")

    students = db.execute(
        select(Student)
        .join(ClassStudent, ClassStudent.student_id == Student.id)
        .where(
            ClassStudent.class_id == class_id,
            ClassStudent.deleted_at.is_(None),
            Student.deleted_at.is_(None),
        )
        .order_by(Student.last_name, Student.first_name)
    ).scalars().all()

    assessments = db.execute(
        select(Assessment).where(
            Assessment.class_id == class_id,
            Assessment.deleted_at.is_(None),
        ).order_by(Assessment.assessed_on.asc())
    ).scalars().all()

    output = io.StringIO()
    output.write("\ufeff")
    writer = csv.writer(output)

    header = ["الرقم", "رقم_التسجيل", "اللقب", "الاسم"]
    for a in assessments:
        header.append(f"{a.title} (/{int(a.max_score)})")
    header.append("المعدل العام (/20)")
    writer.writerow(header)

    for idx, s in enumerate(students, start=1):
        row = [idx, s.external_ref or "", s.last_name, s.first_name]
        student_norms = []
        for a in assessments:
            res = db.execute(
                select(AssessmentResult).where(
                    AssessmentResult.assessment_id == a.id,
                    AssessmentResult.student_id == s.id,
                    AssessmentResult.deleted_at.is_(None),
                )
            ).scalar_one_or_none()
            if res and res.score is not None:
                row.append(f"{float(res.score):.2f}")
                if a.max_score and float(a.max_score) > 0:
                    student_norms.append((float(res.score) / float(a.max_score)) * 20.0)
            else:
                row.append("-")

        gen_avg = f"{round(sum(student_norms) / len(student_norms), 2):.2f}" if student_norms else "-"
        row.append(gen_avg)
        writer.writerow(row)

    csv_data = output.getvalue()
    return Response(
        content=csv_data,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="grades_{school_class.name}.csv"'},
    )


@router.post("/reports/import/students/{class_id}", response_model=ImportRosterResponse)
def import_students_roster(

    class_id: uuid.UUID,
    payload: ImportRosterRequest,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    # Verify teacher and school
    teacher = db.execute(select(Teacher).where(Teacher.id == tid)).scalar_one_or_none()
    if not teacher or not teacher.school_id:
        raise AppError("Teacher profile or associated school not found.")

    school_class = db.execute(
        select(SchoolClass).where(
            SchoolClass.id == class_id,
            SchoolClass.teacher_id == tid,
            SchoolClass.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not school_class:
        raise NotFound(f"Class '{class_id}' not found.")

    rows_to_process: list[ImportRosterRow] = []

    if payload.rows:
        rows_to_process.extend(payload.rows)
    elif payload.csv_content:
        # Parse CSV
        reader = csv.reader(io.StringIO(payload.csv_content.strip()))
        lines = list(reader)
        if not lines:
            raise AppError("CSV content is empty.")

        # Inspect header
        header = [col.strip().lower() for col in lines[0]]
        # Find column indices
        # Support: first_name / prénom / الاسم, last_name / nom / اللقب, reg / external_ref / رقم_التسجيل
        fn_idx, ln_idx, ref_idx = None, None, None
        for i, col in enumerate(header):
            if any(k in col for k in ("first", "prénom", "الاسم", "prenom", "name")):
                fn_idx = i
            elif any(k in col for k in ("last", "nom", "اللقب", "family")):
                ln_idx = i
            elif any(k in col for k in ("ref", "matricule", "تسجيل", "رقم")):
                ref_idx = i

        # Fallback if no header match: assume col 0 is ref (or last), col 1 is last, col 2 is first
        has_header = fn_idx is not None or ln_idx is not None
        start_row = 1 if has_header else 0
        if not has_header:
            if len(lines[0]) >= 3:
                ref_idx, ln_idx, fn_idx = 0, 1, 2
            elif len(lines[0]) >= 2:
                ln_idx, fn_idx = 0, 1

        for line in lines[start_row:]:
            if not line or not any(cell.strip() for cell in line):
                continue
            first_name = line[fn_idx].strip() if fn_idx is not None and fn_idx < len(line) else ""
            last_name = line[ln_idx].strip() if ln_idx is not None and ln_idx < len(line) else ""
            ext_ref = line[ref_idx].strip() if ref_idx is not None and ref_idx < len(line) else None
            if first_name or last_name:
                rows_to_process.append(
                    ImportRosterRow(
                        first_name=first_name or "تلميذ",
                        last_name=last_name or "جديد",
                        registration_number=ext_ref,
                    )
                )

    if not rows_to_process:
        raise AppError("No valid student rows provided to import.")

    total_created = 0
    total_skipped = 0
    errors: list[str] = []

    for idx, row in enumerate(rows_to_process, start=1):
        try:
            fn = row.first_name.strip()
            ln = row.last_name.strip()
            if not fn or not ln:
                total_skipped += 1
                errors.append(f"السطر {idx}: الاسم واللقب مطلوبان.")
                continue

            # Check if student with same name/external_ref already in class
            existing_student = db.execute(
                select(Student)
                .join(ClassStudent, ClassStudent.student_id == Student.id)
                .where(
                    ClassStudent.class_id == class_id,
                    Student.first_name == fn,
                    Student.last_name == ln,
                    Student.deleted_at.is_(None),
                )
            ).scalar_one_or_none()

            if existing_student:
                total_skipped += 1
                continue

            # Create Student
            new_student = Student(
                teacher_id=tid,
                school_id=teacher.school_id,
                first_name=fn,
                last_name=ln,
                external_ref=row.registration_number,
            )
            db.add(new_student)
            db.flush()

            # Link to class
            cs_link = ClassStudent(
                teacher_id=tid,
                class_id=class_id,
                student_id=new_student.id,
            )
            db.add(cs_link)

            # Audit
            audit = AuditLog(
                actor_user_id=principal.user_id,
                teacher_id=tid,
                action="create",
                entity_type="student",
                entity_id=new_student.id,
                after={"first_name": fn, "last_name": ln, "class_id": str(class_id), "source": "csv_import"},
            )
            db.add(audit)
            total_created += 1

        except Exception as ex:
            total_skipped += 1
            errors.append(f"السطر {idx}: {str(ex)}")

    db.commit()

    return ImportRosterResponse(
        total_processed=len(rows_to_process),
        total_created=total_created,
        total_skipped=total_skipped,
        errors=errors[:10],
    )

