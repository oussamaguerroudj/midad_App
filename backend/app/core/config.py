from functools import lru_cache

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_DEV_MARKER = "change-me"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    database_url: str
    jwt_secret: str
    jwt_refresh_secret: str
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    redis_url: str | None = None
    storage_endpoint: str | None = None
    storage_access_key: str | None = None
    storage_secret_key: str | None = None
    storage_bucket: str = "midad-documents"
    cors_origins: str = ""
    max_upload_mb: int = 25

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @model_validator(mode="after")
    def _reject_weak_secrets_in_production(self) -> "Settings":
        if self.is_production:
            for name in ("jwt_secret", "jwt_refresh_secret"):
                value = getattr(self, name)
                if _DEV_MARKER in value or len(value) < 32:
                    raise ValueError(f"{name} is too weak for production")
            if self.jwt_secret == self.jwt_refresh_secret:
                raise ValueError("jwt_secret and jwt_refresh_secret must differ")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
