import os

os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://u:p@localhost:5432/test")
os.environ.setdefault("JWT_SECRET", "test-secret-test-secret-test-secret-1")
os.environ.setdefault("JWT_REFRESH_SECRET", "test-refresh-test-refresh-test-refr-2")
