"""
Webhook endpoints called by Astria when training / generation completes.

Astria POSTs the full tune or prompt object to the callback URL we supply
when creating the tune or prompt.

Endpoints:
  POST /webhooks/astria-tune/{persona_id}   → training complete
  POST /webhooks/astria-prompt/{job_id}     → images ready
"""
import asyncio
import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import AsyncSessionLocal
from app.models.persona import Persona, PersonaStatus
from app.models.generation_job import GenerationJob, GenerationStatus
from app.models.generated_image import GeneratedImage
from app.models.user import User
from app.models.device_token import DeviceToken
from app.services import astria_service, cloudinary_service, notification_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/webhooks", tags=["webhooks"])


@router.post("/astria-tune/{persona_id}", status_code=200)
async def astria_tune_webhook(persona_id: str, request: Request, background_tasks: BackgroundTasks):
    """
    Astria calls this when fine-tuning is complete (or failed).
    Body is the full tune JSON object.
    """
    try:
        tune = await request.json()
    except Exception:
        tune = {}

    logger.info("Astria tune webhook received for persona=%s tune_id=%s", persona_id, tune.get("id"))

    if tune.get("error"):
        logger.error("Astria tune failed for persona %s: %s", persona_id, tune["error"])
        async with AsyncSessionLocal() as db:
            persona = await db.get(Persona, persona_id)
            if persona:
                persona.status = PersonaStatus.failed
                await db.commit()
        return {"ok": True}

    if not tune.get("trained_at"):
        # Still training — Astria sometimes sends intermediate webhooks
        return {"ok": True}

    # Training complete — update persona and kick off any waiting jobs
    background_tasks.add_task(_on_tune_complete, persona_id, tune)
    return {"ok": True}


@router.post("/astria-prompt/{job_id}", status_code=200)
async def astria_prompt_webhook(job_id: str, request: Request, background_tasks: BackgroundTasks):
    """
    Astria calls this when image generation is complete (or failed).
    Body is the full prompt JSON object.
    """
    try:
        prompt = await request.json()
    except Exception:
        prompt = {}

    logger.info("Astria prompt webhook received for job=%s prompt_id=%s images=%d",
                job_id, prompt.get("id"), len(prompt.get("images") or []))

    background_tasks.add_task(_on_prompt_complete, job_id, prompt)
    return {"ok": True}


# ── Background handlers ────────────────────────────────────────────────────────

async def _on_tune_complete(persona_id: str, tune: dict) -> None:
    """Mark persona ready and submit generation for any waiting jobs."""
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(Persona).where(Persona.id == persona_id)
        )
        persona = result.scalar_one_or_none()
        if not persona:
            return

        persona.astria_tune_id = tune["id"]
        persona.status = PersonaStatus.ready
        await db.commit()
        logger.info("Persona %s marked ready (tune %s)", persona_id, tune["id"])

        # Find all queued jobs for this persona and start generation
        jobs_result = await db.execute(
            select(GenerationJob).where(
                GenerationJob.persona_id == persona_id,
                GenerationJob.status == GenerationStatus.queued,
            ).options(
                selectinload(GenerationJob.style_bundle),
                selectinload(GenerationJob.user).selectinload(User.device_tokens),
            )
        )
        waiting_jobs = jobs_result.scalars().all()

    for job in waiting_jobs:
        asyncio.create_task(_submit_and_complete_job(job.id))


async def _submit_and_complete_job(job_id: str) -> None:
    """Submit Astria prompt for a job and wait for webhook to finish it."""
    from app.config import get_settings
    settings = get_settings()

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(GenerationJob).where(GenerationJob.id == job_id)
            .options(
                selectinload(GenerationJob.persona),
                selectinload(GenerationJob.style_bundle),
                selectinload(GenerationJob.user).selectinload(User.device_tokens),
            )
        )
        job = result.unique().scalar_one_or_none()
        if not job or job.status not in (GenerationStatus.queued, GenerationStatus.processing):
            return

        tune_id    = job.persona.astria_tune_id
        style_name = job.style_bundle.name
        subject_kw = job.persona.subject_keyword
        tokens     = [dt.token for dt in job.user.device_tokens if dt.is_active]
        persona_name = job.persona.name

        job.status = GenerationStatus.processing
        await db.commit()

    callback_url = ""
    if settings.app_base_url:
        callback_url = f"{settings.app_base_url.rstrip('/')}/webhooks/astria-prompt/{job_id}"

    try:
        prompt = await asyncio.to_thread(
            astria_service.create_prompts,
            tune_id=tune_id,
            style_name=style_name,
            subject_keyword=subject_kw,
            callback_url=callback_url,
        )
    except Exception as e:
        logger.error("create_prompts failed for job %s: %s", job_id, e)
        async with AsyncSessionLocal() as db:
            job_row = await db.get(GenerationJob, job_id)
            if job_row:
                job_row.status = GenerationStatus.failed
                job_row.error_message = str(e)
                await db.commit()
        notification_service.send_job_failed(tokens, persona_name)
        return

    # Persist the prompt_id immediately so it survives a server restart
    async with AsyncSessionLocal() as db:
        job_row = await db.get(GenerationJob, job_id)
        if job_row:
            job_row.astria_prompt_id = prompt["id"]
            await db.commit()
    logger.info("Astria prompt %s submitted for job %s (webhook: %s)", prompt["id"], job_id, callback_url or "none")


async def _on_prompt_complete(job_id: str, prompt: dict) -> None:
    """Download images from Astria, upload to Cloudinary, mark job complete."""
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(GenerationJob).where(GenerationJob.id == job_id)
            .options(
                selectinload(GenerationJob.persona),
                selectinload(GenerationJob.user).selectinload(User.device_tokens),
            )
        )
        job = result.unique().scalar_one_or_none()
        if not job or job.status == GenerationStatus.completed:
            return
        tokens = [dt.token for dt in job.user.device_tokens if dt.is_active]
        persona_name = job.persona.name

    image_entries = prompt.get("images") or []
    if not image_entries:
        logger.warning("Astria prompt webhook for job %s has no images", job_id)
        async with AsyncSessionLocal() as db:
            job_row = await db.get(GenerationJob, job_id)
            if job_row:
                job_row.status = GenerationStatus.failed
                job_row.error_message = "Astria returned no images"
                await db.commit()
        notification_service.send_job_failed(tokens, persona_name)
        return

    image_urls = [img["url"] for img in image_entries if img.get("url")]
    logger.info("Downloading %d images for job %s", len(image_urls), job_id)

    async with AsyncSessionLocal() as db:
        folder = f"sellface/generated/{job_id}"
        for idx, astria_url in enumerate(image_urls):
            try:
                image_bytes = await asyncio.to_thread(astria_service.download_image, astria_url)
                upload_result = await asyncio.to_thread(
                    cloudinary_service.upload_bytes, image_bytes,
                    folder=folder, public_id=f"{job_id}_{idx}",
                )
                final_url = upload_result["url"]
                cld_id    = upload_result.get("public_id")
            except Exception as e:
                logger.warning("Image %d upload failed for job %s: %s — using direct URL", idx, job_id, e)
                final_url = astria_url
                cld_id    = None

            db.add(GeneratedImage(
                id=str(uuid.uuid4()),
                job_id=job_id,
                image_url=final_url,
                cloudinary_public_id=cld_id,
            ))

        job_row = await db.get(GenerationJob, job_id)
        if job_row:
            job_row.status      = GenerationStatus.completed
            job_row.completed_at = datetime.now(timezone.utc)
        await db.commit()
        logger.info("Job %s completed via webhook with %d images", job_id, len(image_urls))

    notification_service.send_images_ready(tokens, persona_name, job_id)
