import ssl
from celery import Celery
from app.config import get_settings

settings = get_settings()

_use_ssl = settings.celery_broker_url.startswith("rediss://")
_ssl_opts = {"ssl_cert_reqs": ssl.CERT_NONE}

celery_app = Celery(
    "sellface",
    broker=settings.celery_broker_url,
    # No result backend — job status is tracked in PostgreSQL, not Celery results.
    # This avoids MULTI/EXEC commands that Upstash free tier blocks.
    backend=None,
    include=[
        "app.tasks.training",
        "app.tasks.generation",
    ],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_ignore_result=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_routes={
        "app.tasks.training.train_persona": {"queue": "training"},
        "app.tasks.generation.process_generation_job": {"queue": "generation"},
    },
    **({"broker_use_ssl": _ssl_opts} if _use_ssl else {}),
)
