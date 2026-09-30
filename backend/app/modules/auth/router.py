import uuid
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import get_db
from app.core.exceptions import AppError, AuthError, Conflict, ErrorCode, NotFound
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.modules.academic_years.models import AcademicYear
from app.modules.auth.models import RefreshToken, User
from app.modules.auth.schemas import (
    AuthResponse,
    LoginRequest,
    LogoutRequest,
    RefreshTokenRequest,
    RegisterRequest,
    TeacherProfile,
    TokenResponse,
    UserOut,
)
from app.modules.schools.models import School
from app.modules.users.models import Teacher
from app.shared.deps import Principal, current_principal

router = APIRouter(prefix="/auth", tags=["auth"])


def _build_user_out(user: User, teacher: Teacher | None, school_name: str = "") -> UserOut:
    prof = None
    if teacher:
        prof = TeacherProfile(
            id=teacher.id,
            school_id=teacher.school_id,
            school_name=school_name,
            full_name=teacher.full_name,
            photo_key=teacher.photo_key,
            subjects=teacher.subjects,
        )
    return UserOut(id=user.id, email=user.email, locale=user.locale, teacher=prof)


def _issue_tokens(db: Session, user: User, teacher: Teacher | None, device_id: str | None = None) -> TokenResponse:
    s = get_settings()
    extra = {}
    if teacher:
        extra["tid"] = str(teacher.id)
        extra["sid"] = str(teacher.school_id)

    access_token = create_access_token(str(user.id), extra=extra)
    raw_refresh, _, exp = create_refresh_token(str(user.id))

    rf_record = RefreshToken(
        user_id=user.id,
        token_hash=hash_token(raw_refresh),
        device_id=device_id,
        expires_at=exp,
    )
    db.add(rf_record)
    db.flush()

    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh,
        token_type="bearer",
        expires_in=s.access_token_minutes * 60,
    )


@router.post("/register", response_model=AuthResponse)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    # 1. Check existing user
    stmt = select(User).where(User.email == req.email.lower().strip())
    if db.scalar(stmt) is not None:
        raise AppError("Email already registered.", details={"field": "email"})

    # 2. Create user
    user = User(
        email=req.email.lower().strip(),
        password_hash=hash_password(req.password),
        locale=req.locale,
    )
    db.add(user)
    db.flush()

    # 3. Create or find school
    school_name = (req.school_name or "المدرسة الافتراضية").strip()
    school = School(name=school_name)
    db.add(school)
    db.flush()

    # 4. Create teacher
    teacher = Teacher(
        user_id=user.id,
        school_id=school.id,
        full_name=req.full_name.strip(),
    )
    db.add(teacher)
    db.flush()

    # 5. Create default current academic year
    today = date.today()
    start_year = today.year if today.month >= 9 else today.year - 1
    acad_year = AcademicYear(
        school_id=school.id,
        teacher_id=teacher.id,
        label=f"{start_year}-{start_year + 1}",
        starts_on=date(start_year, 9, 1),
        ends_on=date(start_year + 1, 6, 30),
        is_current=True,
    )
    db.add(acad_year)
    db.flush()

    tokens = _issue_tokens(db, user, teacher)
    return AuthResponse(user=_build_user_out(user, teacher, school.name), tokens=tokens)


@router.post("/login", response_model=AuthResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    user = db.scalar(select(User).where(User.email == req.email.lower().strip()))
    if user is None:
        raise AuthError("Invalid email or password.")

    if user.locked_until and user.locked_until > now:
        raise AuthError("Account temporarily locked. Try again later.")

    if not verify_password(req.password, user.password_hash):
        user.failed_logins += 1
        if user.failed_logins >= 5:
            user.locked_until = now + timedelta(minutes=15)
        db.flush()
        raise AuthError("Invalid email or password.")

    # Reset failed attempts
    user.failed_logins = 0
    user.locked_until = None

    teacher = db.scalar(select(Teacher).where(Teacher.user_id == user.id))
    school_name = ""
    if teacher:
        school = db.scalar(select(School).where(School.id == teacher.school_id))
        school_name = school.name if school else ""

    tokens = _issue_tokens(db, user, teacher, device_id=req.device_id)
    return AuthResponse(user=_build_user_out(user, teacher, school_name), tokens=tokens)


@router.post("/refresh", response_model=TokenResponse)
def refresh(req: RefreshTokenRequest, db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    claims = decode_token(req.refresh_token, "refresh")
    user_id = uuid.UUID(claims["sub"])

    token_hash = hash_token(req.refresh_token)
    stmt = select(RefreshToken).where(
        RefreshToken.token_hash == token_hash,
        RefreshToken.user_id == user_id,
    )
    rf_row = db.scalar(stmt)
    if rf_row is None or rf_row.revoked_at is not None or rf_row.expires_at < now:
        raise AuthError("Invalid or expired refresh token.")

    user = db.scalar(select(User).where(User.id == user_id))
    if user is None or not user.is_active:
        raise AuthError("User not found or inactive.")

    teacher = db.scalar(select(Teacher).where(Teacher.user_id == user.id))

    # Rotate refresh token: revoke current
    rf_row.revoked_at = now

    new_tokens = _issue_tokens(db, user, teacher, device_id=req.device_id)
    return new_tokens


@router.post("/logout")
def logout(req: LogoutRequest, db: Session = Depends(get_db)):
    token_hash = hash_token(req.refresh_token)
    rf_row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    if rf_row and rf_row.revoked_at is None:
        rf_row.revoked_at = datetime.now(timezone.utc)
        db.flush()
    return {"message": "Logged out successfully."}


@router.get("/me", response_model=UserOut)
def me(principal: Principal = Depends(current_principal), db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.id == uuid.UUID(principal.user_id)))
    if user is None:
        raise NotFound("User not found.")

    teacher = None
    school_name = ""
    if principal.teacher_id:
        teacher = db.scalar(select(Teacher).where(Teacher.id == uuid.UUID(principal.teacher_id)))
        if teacher:
            school = db.scalar(select(School).where(School.id == teacher.school_id))
            school_name = school.name if school else ""

    return _build_user_out(user, teacher, school_name)
