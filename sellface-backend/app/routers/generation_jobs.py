import asyncio
import uuid
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.persona import Persona, PersonaStatus
from app.models.style_bundle import StyleBundle
from app.models.generation_job import GenerationJob, GenerationStatus
from app.schemas.generation_job import GenerationJobCreate, GenerationJobOut, GenerationJobDetailOut
from app.services.task_runner import run_train_and_generate, run_generate_only

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/generation-jobs", tags=["generation_jobs"])

MIN_IMAGES = 10  # must match personas.py


@router.post("", response_model=GenerationJobOut, status_code=status.HTTP_201_CREATED)
async def create_generation_job(
    body: GenerationJobCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    persona_result = await db.execute(
        select(Persona)
        .where(Persona.id == body.persona_id, Persona.user_id == user.id)
        .options(selectinload(Persona.images))
    )
    persona = persona_result.scalar_one_or_none()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona not found")

    if persona.status == PersonaStatus.failed:
        raise HTTPException(status_code=422, detail="Persona failed — please create a new one")

    if persona.status == PersonaStatus.draft:
        if len(persona.images) < MIN_IMAGES:
            raise HTTPException(
                status_code=422,
                detail=f"Need at least {MIN_IMAGES} photos before generating. Currently have {len(persona.images)}.",
            )

    # Accept either the DB uuid (id) or the StoreKit product_id string
    from sqlalchemy import or_
    style_result = await db.execute(
        select(StyleBundle).where(
            or_(StyleBundle.id == body.style_bundle_id,
                StyleBundle.product_id == body.style_bundle_id),
            StyleBundle.is_active == True,
        )
    )
    style = style_result.scalar_one_or_none()
    if not style:
        raise HTTPException(status_code=404, detail="Style bundle not found")

    # Idempotency: if an in-progress job already exists for this persona+style, return it
    dup = await db.execute(
        select(GenerationJob).where(
            GenerationJob.persona_id == body.persona_id,
            GenerationJob.style_bundle_id == style.id,
            GenerationJob.status.in_([GenerationStatus.queued, GenerationStatus.processing]),
        )
    )
    existing = dup.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="A job for this persona + style is already in progress")

    job = GenerationJob(
        id=str(uuid.uuid4()),
        user_id=user.id,
        persona_id=body.persona_id,
        style_bundle_id=style.id,
        status=GenerationStatus.queued,
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)

    if not persona.astria_tune_id:
        # Training has never been submitted — submit tune first, then generate
        if persona.status == PersonaStatus.draft:
            persona.status = PersonaStatus.processing
            await db.commit()
        asyncio.create_task(run_train_and_generate(persona.id, job.id))
        logger.info("Started train+generate task for persona=%s job=%s", persona.id, job.id)
    elif persona.status == PersonaStatus.ready:
        # Already trained — go straight to generation
        asyncio.create_task(run_generate_only(job.id))
        logger.info("Started generate task for job=%s", job.id)
    else:
        # Tune submitted but training still in progress — leave job queued.
        # The /webhooks/astria-tune webhook will pick up all queued jobs when training completes.
        logger.info("Persona %s still training — job %s queued, webhook will start it", persona.id, job.id)

    return GenerationJobOut.model_validate(job)


@router.get("/{job_id}", response_model=GenerationJobDetailOut)
async def get_generation_job(
    job_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.id == job_id, GenerationJob.user_id == user.id)
        .options(
            selectinload(GenerationJob.generated_images),
            selectinload(GenerationJob.persona),
        )
    )
    job = result.scalar_one_or_none()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    out = GenerationJobDetailOut.model_validate(job)

    # Compute phase so the app can show the right progress message
    if job.status == GenerationStatus.completed:
        out.phase = "completed"
    elif job.status == GenerationStatus.failed:
        out.phase = "failed"
    elif job.persona and job.persona.status in (PersonaStatus.processing, PersonaStatus.uploading):
        out.phase = "training"
    else:
        out.phase = "generating"

    return out
