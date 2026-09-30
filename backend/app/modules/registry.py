"""Imports every model module so Base.metadata is complete (Alembic autogenerate + create_all)."""
from app.core.audit_model import AuditLog  # noqa: F401
from app.modules.academic_years import models as _ay  # noqa: F401
from app.modules.assessments import models as _as  # noqa: F401
from app.modules.assignments import models as _asg  # noqa: F401
from app.modules.attendance import models as _at  # noqa: F401
from app.modules.auth import models as _au  # noqa: F401
from app.modules.backups import models as _bk  # noqa: F401
from app.modules.calendar import models as _cal  # noqa: F401
from app.modules.classes import models as _cl  # noqa: F401
from app.modules.curriculum import models as _cu  # noqa: F401
from app.modules.documents import models as _do  # noqa: F401
from app.modules.lessons import models as _le  # noqa: F401
from app.modules.notifications import models as _no  # noqa: F401
from app.modules.reports import models as _re  # noqa: F401
from app.modules.schools import models as _sc  # noqa: F401
from app.modules.students import models as _st  # noqa: F401
from app.modules.sync import models as _sy  # noqa: F401
from app.modules.tasks import models as _ta  # noqa: F401
from app.modules.users import models as _us  # noqa: F401
