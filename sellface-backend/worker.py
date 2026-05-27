"""
SellFace background worker — polls DB for pending jobs and submits to Astria.

Runs as a separate Render "worker" service alongside the web API.
No Redis, no Celery — just asyncio + Neon PostgreSQL.

Responsibilities:
  1. Submit Astria tune for personas that need training
  2. Submit Astria prompts for trained personas with queued jobs
  3. Recover jobs that got stuck in "processing" without a prompt_id
  4. Webhook-fallback: poll Astria directly for jobs that have been
     processing for too long (in case the webhook never fired)
"""
import asyncio
import logging
import os
import sys
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import selectinload

# Ensure project root is on the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.config import get_settings
from app.database import AsyncSessionLocal
from app.models.persona import Persona, PersonaStatus
from app.models.generation_job import GenerationJob, GenerationStatus
from app.models.generated_image import GeneratedImage
from app.models.user import User
from app.services import astria_service, cloudinary_service, notification_service

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("worker")

POLL_INTERVAL   = 10   # seconds between DB polls
STUCK_THRESHOLD = 300  # seconds before a processing job with no prompt_id is retried
WEBHOOK_FALLBACK_THRESHOLD = 600  # seconds before we check Astria directly as fallback


async def run_forever():
    settings = get_settings()
    logger.info("SellFace worker started (APP_BASE_URL=%s)", settings.app_base_url or "not set")

    while True:
        try:
            await process_all(settings)
        except Exception:
            logger.exception("Worker iteration failed")
        await asyncio.sleep(POLL_INTERVAL)


async def process_all(settings) -> None:
    async with AsyncSessionLocal() as db:
        # ── 1. Recover stuck "processing" jobs ────────────────────────────────
        stuck_cutoff = datetime.now(timezone.utc) - timedelta(seconds=STUCK_THRESHOLD)
        stuck_result = await db.execute(
            select(GenerationJob).where(
                GenerationJob.status == GenerationStatus.processing,
                GenerationJob.astria_prompt_id.is_(None),
                GenerationJob.created_at < stuck_cutoff,
            )
        )
        for job in stuck_result.scalars().all():
            logger.warning("Resetting stuck job %s back to queued", job.id)
            job.status = GenerationStatus.queued
        await db.commit()

    async with AsyncSessionLocal() as db:
        # ── 2. Process queued jobs ─────────────────────────────────────────────
        result = await db.execute(
            select(GenerationJob)
            .where(GenerationJob.status == GenerationStatus.queued)
            .options(
                selectinload(GenerationJob.persona).selectinload(Persona.images),
                selectinload(GenerationJob.style_bundle),
                selectinload(GenerationJob.user).selectinload(User.device_tokens),
            )
        )
        queued_jobs = result.unique().scalars().all()

    for job in queued_jobs:
        await handle_queued_job(job, settings)

    async with AsyncSessionLocal() as db:
        # ── 3. Webhook fallback: check Astria for long-running jobs ───────────
        fallback_cutoff = datetime.now(timezone.utc) - timedelta(seconds=WEBHOOK_FALLBACK_THRESHOLD)
        fallback_result = await db.execute(
            select(GenerationJob).where(
                GenerationJob.status == GenerationStatus.processing,
                GenerationJob.astria_prompt_id.isnot(None),
                GenerationJob.created_at < fallback_cutoff,
            ).options(
                selectinload(GenerationJob.persona),
                selectinload(GenerationJob.style_bundle),
                selectinload(GenerationJob.user).selectinload(User.device_tokens),
            )
        )
        fallback_jobs = fallback_result.unique().scalars().all()

    for job in fallback_jobs:
        await check_astria_fallback(job)


async def handle_queued_job(job: GenerationJob, settings) -> None:
    """Submit tune or prompt to Astria for a queued job."""
    persona = job.persona

    # Training not yet submitted
    if not persona.astria_tune_id:
        await submit_tune(persona, job, settings)
        return

    # Training submitted but not complete
    if persona.status != PersonaStatus.ready:
        logger.debug("Job %s waiting for training (persona %s is %s)", job.id, persona.id, persona.status)
        return

    # Persona ready — submit generation prompt
    await submit_prompt(job, settings)


async def submit_tune(persona: Persona, job: GenerationJob, settings) -> None:
    """Submit fine-tuning to Astria and persist the tune_id."""
    image_urls = [img.remote_url for img in persona.images if img.remote_url]
    if not image_urls:
        logger.error("No training images for persona %s — marking job failed", persona.id)
        async with AsyncSessionLocal() as db:
            j = await db.get(GenerationJob, job.id)
            p = await db.get(Persona, persona.id)
            if j: j.status = GenerationStatus.failed; j.error_message = "No training images"
            if p: p.status = PersonaStatus.failed
            await db.commit()
        return

    callback_url = ""
    if settings.app_base_url:
        callback_url = f"{settings.app_base_url.rstrip('/')}/webhooks/astria-tune/{persona.id}"

    logger.info("Submitting tune for persona %s with %d images", persona.id, len(image_urls))
    try:
        tune = await asyncio.to_thread(
            astria_service.create_tune,
            title=persona.name,
            image_urls=image_urls,
            subject_keyword=persona.subject_keyword,
            callback_url=callback_url,
        )
    except Exception as e:
        logger.error("create_tune failed for persona %s: %s", persona.id, e)
        async with AsyncSessionLocal() as db:
            p = await db.get(Persona, persona.id)
            if p: p.status = PersonaStatus.failed
            await db.commit()
        return

    async with AsyncSessionLocal() as db:
        p = await db.get(Persona, persona.id)
        if p:
            p.astria_tune_id = tune["id"]
            p.status = PersonaStatus.processing
        # Mark this job as processing (it will complete via webhook)
        j = await db.get(GenerationJob, job.id)
        if j: j.status = GenerationStatus.processing
        await db.commit()
    logger.info("Tune %s submitted for persona %s (webhook: %s)", tune["id"], persona.id, callback_url or "none")


async def submit_prompt(job: GenerationJob, settings) -> None:
    """Submit image generation prompt to Astria and persist the prompt_id."""
    callback_url = ""
    if settings.app_base_url:
        callback_url = f"{settings.app_base_url.rstrip('/')}/webhooks/astria-prompt/{job.id}"

    tune_id    = job.persona.astria_tune_id
    style_name = job.style_bundle.name
    subject_kw = job.persona.subject_keyword

    logger.info("Submitting prompt for job %s (tune=%s style=%s)", job.id, tune_id, style_name)
    try:
        prompt = await asyncio.to_thread(
            astria_service.create_prompts,
            tune_id=tune_id,
            style_name=style_name,
            subject_keyword=subject_kw,
            callback_url=callback_url,
        )
    except Exception as e:
        logger.error("create_prompts failed for job %s: %s", job.id, e)
        tokens = [dt.token for dt in job.user.device_tokens if dt.is_active]
        async with AsyncSessionLocal() as db:
            j = await db.get(GenerationJob, job.id)
            if j:
                j.status = GenerationStatus.failed
                j.error_message = str(e)
            await db.commit()
        notification_service.send_job_failed(tokens, job.persona.name)
        return

    async with AsyncSessionLocal() as db:
        j = await db.get(GenerationJob, job.id)
        if j:
            j.status = GenerationStatus.processing
            j.astria_prompt_id = prompt["id"]
        await db.commit()
    logger.info("Prompt %s submitted for job %s (webhook: %s)", prompt["id"], job.id, callback_url or "none")


async def check_astria_fallback(job: GenerationJob) -> None:
    """
    Webhook fallback: directly check Astria for jobs that have been processing
    for too long. Completes them inline if images are ready.
    """
    tune_id   = job.persona.astria_tune_id
    prompt_id = job.astria_prompt_id
    tokens    = [dt.token for dt in job.user.device_tokens if dt.is_active]
    persona_name = job.persona.name

    logger.info("Fallback check: job %s prompt %s", job.id, prompt_id)
    try:
        prompt = await asyncio.to_thread(astria_service.get_prompt, tune_id, prompt_id)
    except Exception as e:
        logger.warning("Fallback get_prompt failed for job %s: %s", job.id, e)
        return

    if not astria_service.are_images_ready(prompt):
        logger.debug("Fallback: job %s images not ready yet", job.id)
        return

    image_urls = [img for img in prompt.get("images", []) if isinstance(img, str) and img]
    if not image_urls:
        return

    logger.info("Fallback completing job %s with %d images", job.id, len(image_urls))
    async with AsyncSessionLocal() as db:
        folder = f"sellface/generated/{job.id}"
        for idx, astria_url in enumerate(image_urls):
            try:
                image_bytes = await asyncio.to_thread(astria_service.download_image, astria_url)
                upload_result = await asyncio.to_thread(
                    cloudinary_service.upload_bytes, image_bytes,
                    folder=folder, public_id=f"{job.id}_{idx}",
                )
                final_url = upload_result["url"]
                cld_id    = upload_result.get("public_id")
            except Exception as e:
                logger.warning("Image %d upload failed for job %s: %s — using direct URL", idx, job.id, e)
                final_url = astria_url
                cld_id    = None

            db.add(GeneratedImage(
                id=str(uuid.uuid4()),
                job_id=job.id,
                image_url=final_url,
                cloudinary_public_id=cld_id,
            ))

        j = await db.get(GenerationJob, job.id)
        if j:
            j.status      = GenerationStatus.completed
            j.completed_at = datetime.now(timezone.utc)
        await db.commit()
        logger.info("Fallback: job %s completed with %d images", job.id, len(image_urls))

    notification_service.send_images_ready(tokens, persona_name, job.id)


if __name__ == "__main__":
    asyncio.run(run_forever())
