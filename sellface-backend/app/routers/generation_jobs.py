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


@router.post("", response_model=GenerationJobOut, status_code=status.HTTP_201_CREATED)
async def create_generation_job(
    body: GenerationJobCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Validate persona belongs to user and has enough images
    persona_result = await db.execute(
        select(Persona)
        .where(Persona.id == body.persona_id, Persona.user_id == user.id)
        .options(selectinload(Persona.images))
    )
    persona = persona_result.scalar_one_or_none()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona not found")
    if persona.status not in (PersonaStatus.ready, PersonaStatus.processing):
        raise HTTPException(status_code=422, detail=f"Persona is not ready (status: {persona.status})")
    if len(persona.images) < 1:
        raise HTTPException(status_code=422, detail="Persona has no uploaded images")

    # Validate style bundle exists
    style_result = await db.execute(
        select(StyleBundle).where(StyleBundle.id == body.style_bundle_id, StyleBundle.is_active == True)
    )
    style = style_result.scalar_one_or_none()
    if not style:
        raise HTTPException(status_code=404, detail="Style bundle not found")

    # Check for duplicate in-progress job
    dup = await db.execute(
        select(GenerationJob).where(
            GenerationJob.persona_id == body.persona_id,
            GenerationJob.style_bundle_id == body.style_bundle_id,
            GenerationJob.status.in_([GenerationStatus.queued, GenerationStatus.processing]),
        )
    )
    if dup.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="A job for this persona + style is already in progress")

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

    # Dispatch Celery task
    task = process_generation_job.apply_async(args=[job.id], queue="generation")
    job.celery_task_id = task.id
    await db.commit()

    logger.info("Queued generation job %s (task %s)", job.id, task.id)
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
