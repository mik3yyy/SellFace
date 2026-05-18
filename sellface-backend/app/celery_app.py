import ssl
from celery import Celery
from app.config import get_settings

settings = get_settings()

celery_app = Celery(
    "sellface",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
    include=[
        "app.tasks.training",
        "app.tasks.generation",
    ],
)

_ssl_opts = {"ssl_cert_reqs": ssl.CERT_NONE}
_use_ssl = settings.celery_broker_url.startswith("rediss://")

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_routes={
        "app.tasks.training.train_persona": {"queue": "training"},
        "app.tasks.generation.process_generation_job": {"queue": "generation"},
    },
    **({"broker_use_ssl": _ssl_opts, "redis_backend_use_ssl": _ssl_opts} if _use_ssl else {}),
)
