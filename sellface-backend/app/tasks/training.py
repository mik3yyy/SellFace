"""
Celery task: train an Astria LoRA model for a persona.

This task is queued automatically after all persona images are uploaded.
It uses Celery's self.retry(countdown=N) to poll Astria without blocking a worker thread.

Flow:
  - First call  → no tune yet → call Astria create_tune(), save tune_id, retry in 60s
  - Retry calls → tune exists → call Astria get_tune()
      - training? → retry again in 60s
      - failed?   → mark persona failed
      - done?     → mark persona ready
"""
import logging
from app.celery_app import celery_app
from app.database_sync import SyncSessionLocal
from app.models.persona import Persona, PersonaStatus
from app.services import astria_service, cloudinary_service

logger = logging.getLogger(__name__)

# Flux training ≈ 20 min, SDXL ≈ 5 min. Allow up to 90 minutes total.
MAX_RETRIES = 90       # × 60s = 90 minutes
POLL_INTERVAL = 60     # seconds between Astria polls


@celery_app.task(
    bind=True,
    name="app.tasks.training.train_persona",
    max_retries=MAX_RETRIES,
    acks_late=True,
)
def train_persona(self, persona_id: str) -> dict:
    db = SyncSessionLocal()
    try:
        persona = db.get(Persona, persona_id)
        if not persona:
            logger.error("train_persona: persona %s not found", persona_id)
            return {"status": "not_found"}

        if persona.status == PersonaStatus.ready:
            logger.info("train_persona: persona %s already ready", persona_id)
            return {"status": "already_ready"}

        # ── Step 1: Submit tune to Astria (first time only) ──────────────────
        if not persona.astria_tune_id:
            image_urls = [img.remote_url for img in persona.images if img.remote_url]
            if not image_urls:
                raise ValueError("Persona has no uploaded images — cannot train")

            tune = astria_service.create_tune(
                title=persona.name,
                image_urls=image_urls,
                subject_keyword=persona.subject_keyword,
            )
            persona.astria_tune_id = tune["id"]
            persona.status = PersonaStatus.processing
            db.commit()
            logger.info("Submitted Astria tune %s for persona %s — will poll in %ds", tune["id"], persona_id, POLL_INTERVAL)
            raise self.retry(countdown=POLL_INTERVAL)

        # ── Step 2: Poll Astria for training completion ──────────────────────
        tune = astria_service.get_tune(persona.astria_tune_id)
        logger.info("Polling Astria tune %s — trained_at=%s", persona.astria_tune_id, tune.get("trained_at"))

        if astria_service.is_tune_failed(tune):
            error = tune.get("error", "Unknown Astria training error")
            logger.error("Astria tune %s failed: %s", persona.astria_tune_id, error)
            persona.status = PersonaStatus.failed
            db.commit()
            return {"status": "failed", "error": error}

        if not astria_service.is_tune_ready(tune):
            logger.info("Astria tune %s still training — retrying in %ds", persona.astria_tune_id, POLL_INTERVAL)
            raise self.retry(countdown=POLL_INTERVAL)

        # ── Step 3: Training complete ─────────────────────────────────────────
        persona.status = PersonaStatus.ready
        db.commit()
        logger.info("Astria tune %s training complete — persona %s is ready", persona.astria_tune_id, persona_id)

        # Delete training images from Cloudinary — Astria has baked them into
        # the LoRA, so we no longer need the originals.
        deleted = 0
        for img in persona.images:
            if img.cloudinary_public_id:
                cloudinary_service.delete_image(img.cloudinary_public_id)
                img.cloudinary_public_id = None
                img.remote_url = None
                deleted += 1
        if deleted:
            db.commit()
            logger.info("Deleted %d training images from Cloudinary for persona %s", deleted, persona_id)

        return {"status": "ready", "tune_id": persona.astria_tune_id}

    except self.MaxRetriesExceededError:
        logger.error("Training timed out for persona %s after %d retries", persona_id, MAX_RETRIES)
        try:
            persona = db.get(Persona, persona_id)
            if persona:
                persona.status = PersonaStatus.failed
                db.commit()
        except Exception:
            pass
        return {"status": "timeout"}

    except astria_service.AstriaAPIError as exc:
        db.rollback()
        logger.error("Astria API error for persona %s (status=%d): %s", persona_id, exc.status_code, exc)
        # Billing / auth errors are permanent — fail immediately instead of retrying
        if exc.status_code in (402, 422, 401, 403):
            try:
                persona = db.get(Persona, persona_id)
                if persona:
                    persona.status = PersonaStatus.failed
                    db.commit()
            except Exception:
                pass
            return {"status": "failed", "error": str(exc)}
        raise self.retry(exc=exc, countdown=POLL_INTERVAL)

    except Exception as exc:
        db.rollback()
        logger.exception("train_persona failed for %s: %s", persona_id, exc)
        raise self.retry(exc=exc, countdown=POLL_INTERVAL)

    finally:
        db.close()
