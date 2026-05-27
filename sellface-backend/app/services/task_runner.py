"""
Async background task runner — submits work to Astria and exits.
Completion is handled by Astria webhooks (POST /webhooks/astria-tune/{id}
and POST /webhooks/astria-prompt/{id}).

Falls back to a short polling loop when APP_BASE_URL is not set (local dev).
"""
import asyncio
import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.database import AsyncSessionLocal
from app.models.persona import Persona, PersonaStatus
from app.models.generation_job import GenerationJob, GenerationStatus
from app.models.generated_image import GeneratedImage
from app.models.user import User
from app.models.device_token import DeviceToken
from app.services import astria_service, cloudinary_service, notification_service

logger = logging.getLogger(__name__)

TRAIN_POLL = 60   # seconds between training polls (fallback only)
GEN_POLL   = 15   # seconds between generation polls (fallback only)


async def run_train_and_generate(persona_id: str, job_id: str) -> None:
    try:
        await _submit_tune(persona_id, job_id)
    except Exception:
        logger.exception("Background task failed: persona=%s job=%s", persona_id, job_id)


async def run_generate_only(job_id: str) -> None:
    try:
        await _submit_prompt(job_id)
    except Exception:
        logger.exception("Generation task failed: job=%s", job_id)


# ── Training submission ────────────────────────────────────────────────────────

async def _submit_tune(persona_id: str, job_id: str) -> None:
    """Submit fine-tuning job to Astria. Webhook handles completion."""
    settings = get_settings()

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(Persona).where(Persona.id == persona_id)
            .options(selectinload(Persona.images))
        )
        persona = result.scalar_one_or_none()
        if not persona or persona.status in (PersonaStatus.ready, PersonaStatus.failed):
            # Already trained — go straight to generation
            await _submit_prompt(job_id)
            return

        if persona.astria_tune_id:
            # Tune exists (may be training) — just submit the prompt
            await _submit_prompt(job_id)
            return

        image_urls = [img.remote_url for img in persona.images if img.remote_url]
        if not image_urls:
            logger.error("No training images for persona %s", persona_id)
            return

        callback_url = ""
        if settings.app_base_url:
            callback_url = f"{settings.app_base_url.rstrip('/')}/webhooks/astria-tune/{persona_id}"

        try:
            tune = await asyncio.to_thread(
                astria_service.create_tune,
                title=persona.name,
                image_urls=image_urls,
                subject_keyword=persona.subject_keyword,
                callback_url=callback_url,
            )
        except Exception as e:
            logger.error("create_tune failed for persona %s: %s", persona_id, e)
            persona.status = PersonaStatus.failed
            await db.commit()
            return

        persona.astria_tune_id = tune["id"]
        persona.status = PersonaStatus.processing
        await db.commit()
        logger.info("Submitted Astria tune %s for persona %s (webhook: %s)",
                    tune["id"], persona_id, callback_url or "polling")

    # If no webhook URL, fall back to polling so it works locally
    if not settings.app_base_url:
        await _poll_tune_then_prompt(persona_id, job_id)


async def _poll_tune_then_prompt(persona_id: str, job_id: str) -> None:
    """Fallback polling used only when APP_BASE_URL is not set (local dev)."""
    for _ in range(90):
        await asyncio.sleep(TRAIN_POLL)
        async with AsyncSessionLocal() as db:
            persona = await db.get(Persona, persona_id)
            if not persona:
                return
            try:
                tune = await asyncio.to_thread(astria_service.get_tune, persona.astria_tune_id)
            except Exception as e:
                logger.warning("get_tune failed: %s — retrying", e)
                continue

            if astria_service.is_tune_failed(tune):
                persona.status = PersonaStatus.failed
                await db.commit()
                return

            if astria_service.is_tune_ready(tune):
                persona.status = PersonaStatus.ready
                await db.commit()
                logger.info("Training complete for persona %s (polling)", persona_id)
                await _submit_prompt(job_id)
                return

    logger.error("Training timed out for persona %s", persona_id)
    async with AsyncSessionLocal() as db:
        persona = await db.get(Persona, persona_id)
        if persona:
            persona.status = PersonaStatus.failed
            await db.commit()


# ── Prompt submission ──────────────────────────────────────────────────────────

async def _submit_prompt(job_id: str) -> None:
    """Submit image generation prompt to Astria. Webhook handles completion."""
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
        if not job or job.status == GenerationStatus.completed:
            return

        tune_id      = job.persona.astria_tune_id
        style_name   = job.style_bundle.name
        subject_kw   = job.persona.subject_keyword
        tokens       = [dt.token for dt in job.user.device_tokens if dt.is_active]
        persona_name = job.persona.name
        persona_status = job.persona.status

        # Wait up to 90 min for training if not ready yet
        if persona_status != PersonaStatus.ready:
            for _ in range(90):
                if job.persona.status == PersonaStatus.ready:
                    break
                if job.persona.status == PersonaStatus.failed:
                    job.status = GenerationStatus.failed
                    job.error_message = "Persona training failed"
                    await db.commit()
                    notification_service.send_job_failed(tokens, persona_name)
                    return
                await asyncio.sleep(TRAIN_POLL)
                await db.refresh(job.persona)
                tune_id = job.persona.astria_tune_id
            else:
                job.status = GenerationStatus.failed
                job.error_message = "Training did not complete in time"
                await db.commit()
                notification_service.send_job_failed(tokens, persona_name)
                return

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

    # Persist prompt_id immediately — survives server restarts
    async with AsyncSessionLocal() as db:
        job_row = await db.get(GenerationJob, job_id)
        if job_row:
            job_row.astria_prompt_id = prompt["id"]
            await db.commit()
    logger.info("Astria prompt %s submitted for job %s (webhook: %s)",
                prompt["id"], job_id, callback_url or "polling")

    # If no webhook URL, fall back to polling
    if not settings.app_base_url:
        await _poll_prompt(job_id, tune_id, prompt["id"], tokens, persona_name)


async def _poll_prompt(job_id: str, tune_id: int, prompt_id: int,
                       tokens: list[str], persona_name: str) -> None:
    """Fallback polling used only when APP_BASE_URL is not set (local dev)."""
    for _ in range(80):
        await asyncio.sleep(GEN_POLL)
        try:
            prompt = await asyncio.to_thread(astria_service.get_prompt, tune_id, prompt_id)
        except Exception as e:
            logger.warning("get_prompt failed for job %s: %s — retrying", job_id, e)
            continue

        if not astria_service.are_images_ready(prompt):
            continue

        image_urls = [img["url"] for img in prompt.get("images", []) if img.get("url")]
        logger.info("Astria returned %d images for job %s (polling)", len(image_urls), job_id)

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
                    logger.warning("Image %d upload failed for job %s: %s", idx, job_id, e)
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
            logger.info("Job %s completed via polling with %d images", job_id, len(image_urls))

        notification_service.send_images_ready(tokens, persona_name, job_id)
        return

    logger.error("Generation timed out for job %s", job_id)
    async with AsyncSessionLocal() as db:
        job_row = await db.get(GenerationJob, job_id)
        if job_row:
            job_row.status = GenerationStatus.failed
            job_row.error_message = "Generation timed out"
            await db.commit()
    notification_service.send_job_failed(tokens, persona_name)
