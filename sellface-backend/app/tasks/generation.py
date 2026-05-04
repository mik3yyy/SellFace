"""
Celery task: generate styled AI images for a job via Astria.

Prerequisites: persona must already have astria_tune_id set and status=ready.

Flow:
  - First call  → no prompt yet → call Astria create_prompts(), save prompt_id, retry in 30s
  - Retry calls → prompt exists → call Astria get_prompt()
      - generating? → retry again in 30s
      - images ready → download each image → upload to Cloudinary → save rows → notify
"""
import logging
import uuid
from datetime import datetime, timezone
from functools import partial

from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.celery_app import celery_app
from app.database_sync import SyncSessionLocal
from app.models.generation_job import GenerationJob, GenerationStatus
from app.models.generated_image import GeneratedImage
from app.models.persona import Persona, PersonaStatus
from app.services import astria_service, cloudinary_service, notification_service

logger = logging.getLogger(__name__)

MAX_RETRIES = 40      # × 30s = 20 minutes max for generation
POLL_INTERVAL = 30    # seconds between Astria polls


@celery_app.task(
    bind=True,
    name="app.tasks.generation.process_generation_job",
    max_retries=MAX_RETRIES,
    acks_late=True,
)
def process_generation_job(self, job_id: str) -> dict:
    db = SyncSessionLocal()
    try:
        # ── Load job with all relationships ──────────────────────────────────
        job = db.execute(
            select(GenerationJob)
            .options(
                joinedload(GenerationJob.persona).joinedload(Persona.images),
                joinedload(GenerationJob.style_bundle),
                joinedload(GenerationJob.user).joinedload(lambda u: u.device_tokens),
            )
            .where(GenerationJob.id == job_id)
        ).unique().scalar_one_or_none()

        if not job:
            logger.error("process_generation_job: job %s not found", job_id)
            return {"status": "not_found"}

        if job.status == GenerationStatus.completed:
            return {"status": "already_completed"}

        # ── Guard: persona must be trained ────────────────────────────────────
        if not job.persona.astria_tune_id:
            raise RuntimeError(
                f"Persona {job.persona_id} has no Astria tune — training must finish before generation"
            )
        if job.persona.status != PersonaStatus.ready:
            raise RuntimeError(
                f"Persona {job.persona_id} is not ready (status={job.persona.status}) — cannot generate yet"
            )

        tune_id = job.persona.astria_tune_id

        # ── Step 1: Submit prompts to Astria (first call only) ────────────────
        if not job.astria_prompt_id:
            job.status = GenerationStatus.processing
            db.commit()

            prompt = astria_service.create_prompts(
                tune_id=tune_id,
                style_name=job.style_bundle.name,
                subject_keyword=job.persona.subject_keyword,
            )
            job.astria_prompt_id = prompt["id"]
            db.commit()
            logger.info(
                "Submitted Astria prompt %s for job %s (tune=%s, style=%s)",
                prompt["id"], job_id, tune_id, job.style_bundle.name,
            )
            raise self.retry(countdown=POLL_INTERVAL)

        # ── Step 2: Poll Astria for generated images ──────────────────────────
        prompt = astria_service.get_prompt(tune_id, job.astria_prompt_id)
        logger.info(
            "Polling Astria prompt %s — images_count=%d",
            job.astria_prompt_id, len(prompt.get("images") or []),
        )

        if not astria_service.are_images_ready(prompt):
            logger.info("Astria still generating — retrying in %ds", POLL_INTERVAL)
            raise self.retry(countdown=POLL_INTERVAL)

        # ── Step 3: Download images from Astria + upload to Cloudinary ────────
        image_urls: list[str] = [img["url"] for img in prompt["images"] if img.get("url")]
        logger.info("Astria returned %d images for job %s", len(image_urls), job_id)

        folder = f"sellface/generated/{job.persona_id}/{job_id}"
        saved = []
        for idx, astria_url in enumerate(image_urls):
            try:
                image_bytes = astria_service.download_image(astria_url)
                public_id = f"{job_id}_{idx}"
                result = cloudinary_service.upload_bytes(image_bytes, folder=folder, public_id=public_id)
                final_url = result["url"]
                cloudinary_public_id = result.get("public_id")
            except Exception as e:
                logger.warning("Failed to download/upload image %d for job %s: %s", idx, job_id, e)
                # Fall back to direct Astria URL so results aren't lost
                final_url = astria_url
                cloudinary_public_id = None

            gen = GeneratedImage(
                id=str(uuid.uuid4()),
                job_id=job_id,
                image_url=final_url,
                cloudinary_public_id=cloudinary_public_id,
            )
            db.add(gen)
            saved.append(gen)

        # ── Step 4: Mark job completed ────────────────────────────────────────
        job.status = GenerationStatus.completed
        job.completed_at = datetime.now(timezone.utc)
        db.commit()
        logger.info("Job %s completed with %d images", job_id, len(saved))

        # ── Step 5: Push notification ─────────────────────────────────────────
        tokens = [dt.token for dt in job.user.device_tokens if dt.is_active]
        notification_service.send_images_ready(tokens, job.persona.name, job_id)

        return {"status": "completed", "image_count": len(saved)}

    except self.MaxRetriesExceededError:
        logger.error("Generation timed out for job %s", job_id)
        _mark_failed(db, job_id, "Generation timed out after maximum retries")
        return {"status": "timeout"}

    except Exception as exc:
        db.rollback()
        logger.exception("process_generation_job failed for %s: %s", job_id, exc)
        if self.request.retries >= self.max_retries:
            _mark_failed(db, job_id, str(exc))
            return {"status": "failed"}
        raise self.retry(exc=exc, countdown=POLL_INTERVAL)

    finally:
        db.close()


def _mark_failed(db, job_id: str, error: str) -> None:
    try:
        job = db.get(GenerationJob, job_id)
        if job and job.status != GenerationStatus.completed:
            job.status = GenerationStatus.failed
            job.error_message = error
            db.commit()
            tokens = [dt.token for dt in job.user.device_tokens if dt.is_active]
            notification_service.send_job_failed(tokens, job.persona.name if job.persona else "Unknown")
    except Exception:
        logger.exception("Failed to mark job %s as failed", job_id)
