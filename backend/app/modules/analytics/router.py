import uuid
from collections import defaultdict
from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import NotFound
from app.modules.assessments.models import Assessment, AssessmentResult
from app.modules.attendance.models import AttendanceRecord, AttendanceSession
from app.modules.classes.models import SchoolClass
from app.modules.students.models import ClassStudent, Student
from app.modules.analytics.schemas import (
    AssessmentTrend,
    AtRiskStudentMetric,
    AttendanceSummary,
    ClassAnalyticsOut,
    ClassOverviewItem,
    GradeDistributionBucket,
    StudentAnalyticsOut,
    StudentAssessmentRecord,
    StudentSummaryMetric,
    TeacherOverviewAnalyticsOut,
)
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/analytics", tags=["analytics"])


def _calculate_attendance_summary(records: list[AttendanceRecord], total_sessions: int) -> AttendanceSummary:
    total_records = len(records)
    present_count = sum(1 for r in records if r.status == "present")
    absent_count = sum(1 for r in records if r.status == "absent")
    late_count = sum(1 for r in records if r.status == "late")
    excused_count = sum(1 for r in records if r.status == "excused")

    att_rate = 0.0
    if total_records > 0:
        att_rate = round(((present_count + late_count) / total_records) * 100.0, 1)

    return AttendanceSummary(
        total_sessions=total_sessions,
        total_records=total_records,
        present_count=present_count,
        absent_count=absent_count,
        late_count=late_count,
        excused_count=excused_count,
        attendance_rate_percent=att_rate,
    )


@router.get("/overview", response_model=TeacherOverviewAnalyticsOut)
def get_teacher_overview(
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    # 1. Classes
    classes = db.execute(
        select(SchoolClass).where(SchoolClass.teacher_id == tid, SchoolClass.deleted_at.is_(None))
    ).scalars().all()
    class_ids = [c.id for c in classes]

    # 2. Students count
    total_students = db.execute(
        select(func.count(Student.id)).where(Student.teacher_id == tid, Student.deleted_at.is_(None))
    ).scalar_one()

    # 3. Total assessments
    total_assessments = db.execute(
        select(func.count(Assessment.id)).where(Assessment.teacher_id == tid, Assessment.deleted_at.is_(None))
    ).scalar_one()

    # 4. Total sessions & attendance
    total_sessions = db.execute(
        select(func.count(AttendanceSession.id)).where(AttendanceSession.teacher_id == tid, AttendanceSession.deleted_at.is_(None))
    ).scalar_one()

    records = db.execute(
        select(AttendanceRecord).where(AttendanceRecord.teacher_id == tid, AttendanceRecord.deleted_at.is_(None))
    ).scalars().all()
    global_att = _calculate_attendance_summary(records, total_sessions)

    # 5. Global grade average (normalized / 20)
    results = db.execute(
        select(AssessmentResult.score, Assessment.max_score)
        .join(Assessment, Assessment.id == AssessmentResult.assessment_id)
        .where(
            Assessment.teacher_id == tid,
            AssessmentResult.deleted_at.is_(None),
            AssessmentResult.score.is_not(None),
        )
    ).all()

    norm_scores = []
    for score, max_score in results:
        if max_score and float(max_score) > 0 and score is not None:
            norm_scores.append((float(score) / float(max_score)) * 20.0)

    overall_avg = round(sum(norm_scores) / len(norm_scores), 2) if norm_scores else 0.0

    # 6. Class summaries
    class_summaries: list[ClassOverviewItem] = []
    total_at_risk = 0

    for c in classes:
        # student count in class
        s_count = db.execute(
            select(func.count(ClassStudent.student_id)).where(
                ClassStudent.class_id == c.id, ClassStudent.deleted_at.is_(None)
            )
        ).scalar_one()

        # class assessments & results
        c_results = db.execute(
            select(AssessmentResult.score, Assessment.max_score)
            .join(Assessment, Assessment.id == AssessmentResult.assessment_id)
            .where(
                Assessment.class_id == c.id,
                AssessmentResult.deleted_at.is_(None),
                AssessmentResult.score.is_not(None),
            )
        ).all()
        c_scores = [
            (float(s) / float(m)) * 20.0 for s, m in c_results if m and float(m) > 0 and s is not None
        ]
        c_avg = round(sum(c_scores) / len(c_scores), 2) if c_scores else 0.0

        # class attendance
        c_records = db.execute(
            select(AttendanceRecord)
            .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
            .where(AttendanceSession.class_id == c.id, AttendanceRecord.deleted_at.is_(None))
        ).scalars().all()
        c_att = _calculate_attendance_summary(c_records, 0)

        # at-risk students in class (absences >= 3 or avg < 10)
        c_student_ids = db.execute(
            select(ClassStudent.student_id).where(
                ClassStudent.class_id == c.id, ClassStudent.deleted_at.is_(None)
            )
        ).scalars().all()

        at_risk_in_class = 0
        for sid in c_student_ids:
            s_absences = sum(1 for r in c_records if r.student_id == sid and r.status in ("absent", "late"))
            s_res = [
                (float(s) / float(m)) * 20.0
                for s, m, st_id in db.execute(
                    select(AssessmentResult.score, Assessment.max_score, AssessmentResult.student_id)
                    .join(Assessment, Assessment.id == AssessmentResult.assessment_id)
                    .where(
                        Assessment.class_id == c.id,
                        AssessmentResult.student_id == sid,
                        AssessmentResult.deleted_at.is_(None),
                        AssessmentResult.score.is_not(None),
                    )
                ).all()
                if m and float(m) > 0 and s is not None
            ]
            s_avg = (sum(s_res) / len(s_res)) if s_res else None
            if s_absences >= 3 or (s_avg is not None and s_avg < 10.0):
                at_risk_in_class += 1

        total_at_risk += at_risk_in_class

        class_summaries.append(
            ClassOverviewItem(
                class_id=c.id,
                class_name=c.name,
                student_count=s_count,
                average_score=c_avg,
                attendance_rate_percent=c_att.attendance_rate_percent,
                at_risk_count=at_risk_in_class,
            )
        )

    return TeacherOverviewAnalyticsOut(
        total_students=total_students,
        total_classes=len(classes),
        total_assessments=total_assessments,
        total_attendance_sessions=total_sessions,
        overall_attendance_rate=global_att.attendance_rate_percent,
        overall_average_score=overall_avg,
        total_at_risk_students=total_at_risk,
        class_summaries=class_summaries,
    )


@router.get("/classes/{class_id}", response_model=ClassAnalyticsOut)
def get_class_analytics(
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

    # 1. Students in class
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

    # 2. Assessments in class
    assessments = db.execute(
        select(Assessment).where(
            Assessment.class_id == class_id,
            Assessment.deleted_at.is_(None),
        ).order_by(Assessment.assessed_on.asc(), Assessment.created_at.asc())
    ).scalars().all()

    # 3. Assessment results per student
    student_scores: dict[uuid.UUID, list[float]] = defaultdict(list)
    assessment_scores: dict[uuid.UUID, list[float]] = defaultdict(list)

    all_normalized_scores: list[float] = []

    for a in assessments:
        results = db.execute(
            select(AssessmentResult).where(
                AssessmentResult.assessment_id == a.id,
                AssessmentResult.deleted_at.is_(None),
                AssessmentResult.score.is_not(None),
            )
        ).scalars().all()
        for r in results:
            if a.max_score and float(a.max_score) > 0 and r.score is not None:
                norm = (float(r.score) / float(a.max_score)) * 20.0
                student_scores[r.student_id].append(norm)
                assessment_scores[a.id].append(norm)
                all_normalized_scores.append(norm)

    # Class metrics
    avg_score = round(sum(all_normalized_scores) / len(all_normalized_scores), 2) if all_normalized_scores else 0.0
    min_score = round(min(all_normalized_scores), 2) if all_normalized_scores else 0.0
    max_score = round(max(all_normalized_scores), 2) if all_normalized_scores else 0.0

    # Student averages and rankings
    student_averages: list[StudentSummaryMetric] = []
    for s in students:
        scs = student_scores.get(s.id, [])
        s_avg = round(sum(scs) / len(scs), 2) if scs else 0.0
        student_averages.append(
            StudentSummaryMetric(
                student_id=s.id,
                student_name=f"{s.first_name} {s.last_name}",
                average_score=s_avg,
            )
        )

    student_averages.sort(key=lambda x: x.average_score, reverse=True)
    for idx, s in enumerate(student_averages, start=1):
        s.rank = idx

    # Pass rate: % of students with avg >= 10.0
    passing_students = sum(1 for s in student_averages if s.average_score >= 10.0)
    pass_rate = round((passing_students / len(student_averages)) * 100.0, 1) if student_averages else 0.0

    # 4. Grade distribution buckets (based on student averages)
    buckets = [
        {"key": "below_10", "label": "دون المتوسط (< 10)", "min": 0.0, "max": 9.99, "count": 0},
        {"key": "average", "label": "متوسط (10 - 11.99)", "min": 10.0, "max": 11.99, "count": 0},
        {"key": "good", "label": "حسن (12 - 13.99)", "min": 12.0, "max": 13.99, "count": 0},
        {"key": "very_good", "label": "جيد جداً (14 - 15.99)", "min": 14.0, "max": 15.99, "count": 0},
        {"key": "excellent", "label": "ممتاز (16 - 20)", "min": 16.0, "max": 20.0, "count": 0},
    ]
    for s in student_averages:
        for b in buckets:
            if b["min"] <= s.average_score <= b["max"] or (b["key"] == "excellent" and s.average_score >= 16.0):
                b["count"] += 1
                break

    dist_out: list[GradeDistributionBucket] = []
    tot = len(student_averages) or 1
    for b in buckets:
        pct = round((b["count"] / tot) * 100.0, 1)
        dist_out.append(
            GradeDistributionBucket(
                key=b["key"],
                label=b["label"],
                min_score=b["min"],
                max_score=b["max"],
                count=b["count"],
                percentage=pct,
            )
        )

    # 5. Attendance stats
    sessions = db.execute(
        select(AttendanceSession).where(
            AttendanceSession.class_id == class_id,
            AttendanceSession.deleted_at.is_(None),
        )
    ).scalars().all()
    session_ids = [sess.id for sess in sessions]

    records = []
    if session_ids:
        records = db.execute(
            select(AttendanceRecord).where(
                AttendanceRecord.session_id.in_(session_ids),
                AttendanceRecord.deleted_at.is_(None),
            )
        ).scalars().all()

    att_summary = _calculate_attendance_summary(records, len(sessions))

    # 6. At-risk students
    at_risk: list[AtRiskStudentMetric] = []
    for s in students:
        s_abs = sum(1 for r in records if r.student_id == s.id and r.status in ("absent", "late"))
        scs = student_scores.get(s.id, [])
        s_avg = round(sum(scs) / len(scs), 2) if scs else None

        reasons = []
        if s_abs >= 5:
            reasons.append(f"غياب متكرر ({s_abs} حصص)")
        elif s_abs >= 3:
            reasons.append(f"تنبيه غياب ({s_abs} حصص)")

        if s_avg is not None and s_avg < 10.0:
            reasons.append(f"معدل تحصيلي ضعيف ({s_avg}/20)")

        if reasons:
            severity = "danger" if (s_abs >= 5 or (s_avg is not None and s_avg < 8.0)) else "warning"
            at_risk.append(
                AtRiskStudentMetric(
                    student_id=s.id,
                    student_name=f"{s.first_name} {s.last_name}",
                    average_score=s_avg,
                    absent_count=s_abs,
                    risk_reason=" • ".join(reasons),
                    severity=severity,
                )
            )

    # 7. Assessment trends
    trends: list[AssessmentTrend] = []
    for a in assessments:
        scs = assessment_scores.get(a.id, [])
        a_avg = round(sum(scs) / len(scs), 2) if scs else 0.0
        trends.append(
            AssessmentTrend(
                assessment_id=a.id,
                title=a.title,
                kind=a.kind,
                max_score=float(a.max_score),
                assessed_on=a.assessed_on,
                average_score=a_avg,
            )
        )

    return ClassAnalyticsOut(
        class_id=school_class.id,
        class_name=school_class.name,
        student_count=len(students),
        average_score=avg_score,
        min_score=min_score,
        max_score=max_score,
        pass_rate_percent=pass_rate,
        grade_distribution=dist_out,
        attendance=att_summary,
        top_students=student_averages[:5],
        at_risk_students=at_risk,
        assessment_trends=trends,
    )


@router.get("/students/{student_id}", response_model=StudentAnalyticsOut)
def get_student_analytics(
    student_id: uuid.UUID,
    principal: Principal = Depends(current_principal),
    db: Session = Depends(get_db),
):
    if not principal.teacher_id:
        raise NotFound("Teacher profile not found.")
    tid = uuid.UUID(principal.teacher_id)

    student = db.execute(
        select(Student).where(
            Student.id == student_id,
            Student.teacher_id == tid,
            Student.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if not student:
        raise NotFound(f"Student '{student_id}' not found.")

    # Enrollment
    cs = db.execute(
        select(ClassStudent, SchoolClass)
        .join(SchoolClass, SchoolClass.id == ClassStudent.class_id)
        .where(
            ClassStudent.student_id == student_id,
            ClassStudent.deleted_at.is_(None),
            SchoolClass.deleted_at.is_(None),
        )
    ).first()

    class_id = cs[1].id if cs else uuid.UUID(int=0)
    class_name = cs[1].name if cs else "بدون قسم"

    # All students in same class to determine rank
    class_students = []
    if cs:
        class_students = db.execute(
            select(Student.id)
            .join(ClassStudent, ClassStudent.student_id == Student.id)
            .where(
                ClassStudent.class_id == class_id,
                ClassStudent.deleted_at.is_(None),
                Student.deleted_at.is_(None),
            )
        ).scalars().all()

    # Assessments in class
    assessments = db.execute(
        select(Assessment).where(
            Assessment.class_id == class_id,
            Assessment.deleted_at.is_(None),
        ).order_by(Assessment.assessed_on.asc())
    ).scalars().all()

    history: list[StudentAssessmentRecord] = []
    my_norm_scores: list[float] = []

    # Map of all student scores in class to compute rankings
    peer_scores: dict[uuid.UUID, list[float]] = defaultdict(list)

    for a in assessments:
        results = db.execute(
            select(AssessmentResult).where(
                AssessmentResult.assessment_id == a.id,
                AssessmentResult.deleted_at.is_(None),
                AssessmentResult.score.is_not(None),
            )
        ).scalars().all()

        class_scs = []
        my_res = None
        for r in results:
            if a.max_score and float(a.max_score) > 0 and r.score is not None:
                norm = (float(r.score) / float(a.max_score)) * 20.0
                class_scs.append(norm)
                peer_scores[r.student_id].append(norm)
                if r.student_id == student_id:
                    my_res = r

        c_avg = round(sum(class_scs) / len(class_scs), 2) if class_scs else None
        if my_res:
            my_norm = (float(my_res.score) / float(a.max_score)) * 20.0 if a.max_score else 0.0
            my_norm_scores.append(my_norm)
            history.append(
                StudentAssessmentRecord(
                    assessment_id=a.id,
                    title=a.title,
                    kind=a.kind,
                    max_score=float(a.max_score),
                    score=float(my_res.score),
                    normalized_20=round(my_norm, 2),
                    class_average=c_avg,
                    assessed_on=a.assessed_on,
                )

            )

    student_avg = round(sum(my_norm_scores) / len(my_norm_scores), 2) if my_norm_scores else 0.0

    # Rank calculation
    peer_averages = []
    for sid in class_students:
        scs = peer_scores.get(sid, [])
        p_avg = (sum(scs) / len(scs)) if scs else 0.0
        peer_averages.append((sid, p_avg))

    peer_averages.sort(key=lambda x: x[1], reverse=True)
    my_rank = 1
    for idx, (sid, _) in enumerate(peer_averages, start=1):
        if sid == student_id:
            my_rank = idx
            break

    # Attendance
    records = db.execute(
        select(AttendanceRecord).where(
            AttendanceRecord.student_id == student_id,
            AttendanceRecord.deleted_at.is_(None),
        )
    ).scalars().all()

    total_class_sessions = db.execute(
        select(func.count(AttendanceSession.id)).where(
            AttendanceSession.class_id == class_id,
            AttendanceSession.deleted_at.is_(None),
        )
    ).scalar_one() if cs else 0

    att_summary = _calculate_attendance_summary(records, total_class_sessions)

    # Strengths and areas for growth
    strengths: list[str] = []
    areas_for_growth: list[str] = []

    if att_summary.attendance_rate_percent >= 90.0:
        strengths.append(f"انضباط ممتاز وحضور منتظم ({att_summary.attendance_rate_percent}%)")
    elif att_summary.attendance_rate_percent < 75.0:
        areas_for_growth.append(f"نسبة الغياب مرتفعة ({att_summary.absent_count} غيابات)")

    if student_avg >= 14.0:
        strengths.append(f"معدل تحصيلي عام متفوق ({student_avg}/20)")
    elif student_avg >= 10.0:
        strengths.append(f"مستوى دراسي مستقر ومقبول ({student_avg}/20)")
    else:
        areas_for_growth.append(f"المعدل العام أقل من عتبة النجاح ({student_avg}/20)")

    for h in history:
        if h.normalized_20 and h.normalized_20 >= 16.0:
            strengths.append(f"أداء متميز في {h.title} ({h.normalized_20}/20)")
        elif h.normalized_20 and h.normalized_20 < 9.0:
            areas_for_growth.append(f"صعوبة في استيعاب {h.title} ({h.normalized_20}/20)")

    return StudentAnalyticsOut(
        student_id=student.id,
        student_name=f"{student.first_name} {student.last_name}",
        class_id=class_id,
        class_name=class_name,
        average_score=student_avg,
        rank_in_class=my_rank,
        total_students_in_class=len(class_students),
        attendance=att_summary,
        assessments_history=history,
        strengths=strengths[:4],
        areas_for_growth=areas_for_growth[:4],
    )
