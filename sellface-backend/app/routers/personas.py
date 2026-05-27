import uuid
import asyncio
import logging
from functools import partial
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.persona import Persona, PersonaStatus
from app.models.persona_image import PersonaImage
from app.models.generation_job import GenerationJob, GenerationStatus
from app.models.generated_image import GeneratedImage
from app.models.style_bundle import StyleBundle
from app.schemas.persona import PersonaCreate, PersonaOut, PersonaDetailOut, PersonaImageOut
from app.schemas.generation_job import GeneratedImageOut
from app.services import cloudinary_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/personas", tags=["personas"])

MAX_IMAGES = 15
MIN_IMAGES = 10


@router.post("", response_model=PersonaOut, status_code=status.HTTP_201_CREATED)
async def create_persona(
    body: PersonaCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    persona = Persona(
        id=str(uuid.uuid4()),
        user_id=user.id,
        name=body.name,
        subject_keyword=body.subject_keyword,
        status=PersonaStatus.draft,
    )
    db.add(persona)
    await db.commit()
    await db.refresh(persona)
    out = PersonaOut.model_validate(persona)
    out.image_count = 0
    return out


@router.get("", response_model=list[PersonaOut])
async def list_personas(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Persona)
        .where(Persona.user_id == user.id)
        .options(selectinload(Persona.images))
        .order_by(Persona.created_at.desc())
    )
    personas = result.scalars().all()
    out = []
    for p in personas:
        o = PersonaOut.model_validate(p)
        o.image_count = len(p.images)
        out.append(o)
    return out


@router.get("/{persona_id}", response_model=PersonaDetailOut)
async def get_persona(
    persona_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Persona)
        .where(Persona.id == persona_id, Persona.user_id == user.id)
        .options(selectinload(Persona.images))
    )
    persona = result.scalar_one_or_none()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona not found")

    out = PersonaDetailOut.model_validate(persona)
    out.image_count = len(persona.images)
    out.images = [PersonaImageOut.model_validate(i) for i in persona.images]
    return out


@router.post("/{persona_id}/images", response_model=list[PersonaImageOut], status_code=status.HTTP_201_CREATED)
async def upload_persona_images(
    persona_id: str,
    files: list[UploadFile] = File(...),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Upload 10–15 photos for a persona.
    On reaching MIN_IMAGES, automatically triggers Astria LoRA training.
    """
    result = await db.execute(
        select(Persona)
        .where(Persona.id == persona_id, Persona.user_id == user.id)
        .options(selectinload(Persona.images))
    )
    persona = result.scalar_one_or_none()
    if not persona:
        raise HTTPException(status_code=404, detail="Persona not found")

    existing_count = len(persona.images)
    if existing_count + len(files) > MAX_IMAGES:
        raise HTTPException(
            status_code=422,
            detail=f"Too many images. Max {MAX_IMAGES}, currently have {existing_count}.",
        )
    if len(files) < 1:
        raise HTTPException(status_code=422, detail="At least 1 image file required")

    persona.status = PersonaStatus.uploading
    saved = []

    for file in files:
        if not file.content_type or not file.content_type.startswith("image/"):
            raise HTTPException(status_code=422, detail=f"'{file.filename}' is not an image")

        data = await file.read()
        image_id = str(uuid.uuid4())

        try:
            upload_result = await _upload_to_cloudinary(data, persona_id, image_id)
        except Exception as e:
            logger.exception("Cloudinary upload failed for %s", file.filename)
            raise HTTPException(status_code=502, detail=f"Image upload failed: {e}")

        pi = PersonaImage(
            id=image_id,
            persona_id=persona_id,
            remote_url=upload_result["url"],
            cloudinary_public_id=upload_result.get("public_id"),
        )
        db.add(pi)
        saved.append(pi)

        if not persona.cover_image_url:
            persona.cover_image_url = upload_result["url"]

    total_images = existing_count + len(saved)
    # Stay in draft — training is triggered later when the user picks a style.
    persona.status = PersonaStatus.draft
    await db.commit()
    logger.info("Persona %s has %d/%d images uploaded", persona_id, total_images, MIN_IMAGES)

    return [PersonaImageOut.model_validate(i) for i in saved]


@router.get("/{persona_id}/results", response_model=list[GeneratedImageOut])
async def get_persona_results(
    persona_id: str,
    style_bundle_id: str | None = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = (
        select(GeneratedImage)
        .join(GenerationJob, GeneratedImage.job_id == GenerationJob.id)
        .where(
            GenerationJob.persona_id == persona_id,
            GenerationJob.user_id == user.id,
            GenerationJob.status == GenerationStatus.completed,
        )
        .order_by(GeneratedImage.created_at.desc())
    )
    if style_bundle_id:
        # Accept short slug ("linkedin"), product_id ("com.sellface.style.linkedin"), or UUID
        sb_res = await db.execute(
            select(StyleBundle.id).where(
                or_(StyleBundle.id == style_bundle_id, StyleBundle.product_id == style_bundle_id)
            )
        )
        resolved_id = sb_res.scalar_one_or_none() or style_bundle_id
        query = query.where(GenerationJob.style_bundle_id == resolved_id)

    result = await db.execute(query)
    return [GeneratedImageOut.model_validate(i) for i in result.scalars().all()]


# ── Helpers ────────────────────────────────────────────────────────────────────

async def _upload_to_cloudinary(data: bytes, persona_id: str, image_id: str) -> dict:
    folder = f"sellface/personas/{persona_id}"
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None,
        partial(cloudinary_service.upload_bytes, data, folder, image_id),
    )


