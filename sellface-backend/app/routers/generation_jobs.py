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
from app.tasks.generation import process_generation_job

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

    style_result = await db.execute(
        select(StyleBundle).where(StyleBundle.id == body.style_bundle_id, StyleBundle.is_active == True)
    )
    style = style_result.scalar_one_or_none()
    if not style:
        raise HTTPException(status_code=404, detail="Style bundle not found")

    # Idempotency: if an in-progress job already exists for this persona+style, return it
    dup = await db.execute(
        select(GenerationJob).where(
            GenerationJob.persona_id == body.persona_id,
            GenerationJob.style_bundle_id == body.style_bundle_id,
            GenerationJob.status.in_([GenerationStatus.queued, GenerationStatus.processing]),
        )
    )
    existing = dup.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="A job for this persona + style is already in progress")

    # If persona has photos but training hasn't started yet, kick it off now.
    if persona.status == PersonaStatus.draft and not persona.astria_tune_id:
        from app.tasks.training import train_persona
        persona.status = PersonaStatus.processing
        await db.commit()
        task = train_persona.apply_async(args=[persona.id], queue="training")
        logger.info("Started training for persona %s (task=%s) on first style selection", persona.id, task.id)

    job = GenerationJob(
        id=str(uuid.uuid4()),
        user_id=user.id,
        persona_id=body.persona_id,
        style_bundle_id=body.style_bundle_id,
        status=GenerationStatus.queued,
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)

    task = process_generation_job.apply_async(args=[job.id], queue="generation")
    job.celery_task_id = task.id
    await db.commit()

    logger.info("Queued generation job %s (task=%s)", job.id, task.id)
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
        .options(selectinload(GenerationJob.generated_images))
    )
    job = result.scalar_one_or_none()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return GenerationJobDetailOut.model_validate(job)
