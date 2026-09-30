import datetime
import uuid
from pydantic import BaseModel



class GradeDistributionBucket(BaseModel):
    key: str
    label: str
    min_score: float
    max_score: float
    count: int
    percentage: float


class StudentSummaryMetric(BaseModel):
    student_id: uuid.UUID
    student_name: str
    average_score: float
    rank: int | None = None


class AtRiskStudentMetric(BaseModel):
    student_id: uuid.UUID
    student_name: str
    average_score: float | None = None
    absent_count: int
    risk_reason: str
    severity: str  # "warning" or "danger"


class AssessmentTrend(BaseModel):
    assessment_id: uuid.UUID
    title: str
    kind: str
    max_score: float
    assessed_on: datetime.date | None = None
    average_score: float


class AttendanceSummary(BaseModel):
    total_sessions: int
    total_records: int
    present_count: int
    absent_count: int
    late_count: int
    excused_count: int
    attendance_rate_percent: float


class ClassAnalyticsOut(BaseModel):
    class_id: uuid.UUID
    class_name: str
    student_count: int
    average_score: float
    min_score: float
    max_score: float
    pass_rate_percent: float
    grade_distribution: list[GradeDistributionBucket]
    attendance: AttendanceSummary
    top_students: list[StudentSummaryMetric]
    at_risk_students: list[AtRiskStudentMetric]
    assessment_trends: list[AssessmentTrend]


class StudentAssessmentRecord(BaseModel):
    assessment_id: uuid.UUID
    title: str
    kind: str
    max_score: float
    score: float | None = None
    normalized_20: float | None = None
    class_average: float | None = None
    assessed_on: datetime.date | None = None


class StudentAnalyticsOut(BaseModel):
    student_id: uuid.UUID
    student_name: str
    class_id: uuid.UUID
    class_name: str
    average_score: float
    rank_in_class: int
    total_students_in_class: int
    attendance: AttendanceSummary
    assessments_history: list[StudentAssessmentRecord]
    strengths: list[str]
    areas_for_growth: list[str]


class ClassOverviewItem(BaseModel):
    class_id: uuid.UUID
    class_name: str
    student_count: int
    average_score: float
    attendance_rate_percent: float
    at_risk_count: int


class TeacherOverviewAnalyticsOut(BaseModel):
    total_students: int
    total_classes: int
    total_assessments: int
    total_attendance_sessions: int
    overall_attendance_rate: float
    overall_average_score: float
    total_at_risk_students: int
    class_summaries: list[ClassOverviewItem]
