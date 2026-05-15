from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import model_validator
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database
    database_url: str = "postgresql+asyncpg://sellface:sellface@localhost:5432/sellface"
    database_url_sync: str = "postgresql+psycopg2://sellface:sellface@localhost:5432/sellface"

    @model_validator(mode="after")
    def normalise_db_urls(self) -> "Settings":
        # Render provides postgres:// or postgresql:// — attach correct async/sync drivers
        def _fix(url: str, driver: str) -> str:
            if url.startswith("postgres://"):
                return f"postgresql+{driver}" + url[len("postgres"):]
            if url.startswith("postgresql://"):
                return f"postgresql+{driver}" + url[len("postgresql"):]
            return url
        self.database_url = _fix(self.database_url, "asyncpg")
        self.database_url_sync = _fix(self.database_url_sync, "psycopg2")
        return self

    # Redis / Celery
    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/0"
    celery_result_backend: str = "redis://localhost:6379/0"

    # Cloudinary
    cloudinary_cloud_name: str = ""
    cloudinary_api_key: str = ""
    cloudinary_api_secret: str = ""

    # Astria.ai
    astria_api_key: str = ""
    astria_base_url: str = "https://api.astria.ai"
    astria_branch: str = "flux1"
    astria_images_per_job: int = 8

    # App
    app_name: str = "SellFace API"
    debug: bool = False
    secret_key: str = "change-me-in-production"
    admin_secret: str = "change-admin-secret-in-production"

    # APNs — leave empty to disable push notifications
    apns_key_id: str = ""
    apns_team_id: str = ""
    # Store the .p8 key content with literal \n between lines, e.g.:
    #   APNS_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nMIGH...\n-----END PRIVATE KEY-----
    apns_private_key: str = ""
    apns_bundle_id: str = "com.mike.SellFace"
    apns_use_sandbox: bool = True  # set to false in production

    @property
    def apns_configured(self) -> bool:
        return bool(self.apns_key_id and self.apns_team_id and self.apns_private_key)

    @property
    def apns_private_key_pem(self) -> str:
        """Decode escaped newlines stored in env vars back to actual newlines."""
        return self.apns_private_key.replace("\\n", "\n")

    @property
    def cloudinary_configured(self) -> bool:
        return bool(self.cloudinary_cloud_name and self.cloudinary_api_key and self.cloudinary_api_secret)

    @property
    def astria_configured(self) -> bool:
        return bool(self.astria_api_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()
