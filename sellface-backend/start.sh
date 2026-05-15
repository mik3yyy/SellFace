#!/bin/bash
set -e

case "$SERVICE_ROLE" in
  api)
    echo "Running migrations..."
    alembic upgrade head
    echo "Starting API..."
    exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
    ;;
  worker-training)
    exec celery -A app.celery_app worker --loglevel=info --queues=training --concurrency=2
    ;;
  worker-generation)
    exec celery -A app.celery_app worker --loglevel=info --queues=generation --concurrency=2
    ;;
  *)
    # Local default — run the API
    exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
    ;;
esac
