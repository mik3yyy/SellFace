from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database
    database_url: str = "postgresql+asyncpg://sellface:sellface@localhost:5432/sellface"
    database_url_sync: str = "postgresql+psycopg2://sellface:sellface@localhost:5432/sellface"

    # Redis / Celery
    redis_url: str = "rediss://default:yourpassword@your-endpoint.upstash.io:6379"
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

    # APNs
    apns_key_id: str = ""
    apns_team_id: str = ""
    apns_bundle_id: str = "com.mike.SellFace"


@lru_cache
def get_settings() -> Settings:
    return Settings()
