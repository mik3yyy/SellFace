import ssl
from celery import Celery
from app.config import get_settings

settings = get_settings()

_broker_url = settings.celery_broker_url
_use_redis_ssl = _broker_url.startswith("rediss://")

celery_app = Celery(
    "sellface",
    broker=_broker_url,
    backend=None,  # job status tracked in PostgreSQL — no result backend needed
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
    # Upstash Redis uses TLS — must set ssl_cert_reqs or the client refuses to connect
    broker_use_ssl={"ssl_cert_reqs": ssl.CERT_NONE} if _use_redis_ssl else None,
    task_routes={
        "app.tasks.training.train_persona": {"queue": "training"},
        "app.tasks.generation.process_generation_job": {"queue": "generation"},
    },
)
