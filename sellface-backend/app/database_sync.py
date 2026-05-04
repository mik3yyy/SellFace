"""Synchronous SQLAlchemy session for Celery workers."""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from app.config import get_settings

settings = get_settings()

sync_engine = create_engine(
    settings.database_url_sync,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
)

SyncSessionLocal = sessionmaker(bind=sync_engine, autocommit=False, autoflush=False)


def get_sync_db() -> Session:
    db = SyncSessionLocal()
    try:
        yield db
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
