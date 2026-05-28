from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, case
from typing import Optional
from pydantic import BaseModel
import asyncio
import logging

from app.database import AsyncSessionLocal
from app.models.user import User
from app.models.persona import Persona, PersonaStatus
from app.models.generation_job import GenerationJob, GenerationStatus
from app.models.generated_image import GeneratedImage
from app.models.style_bundle import StyleBundle
from app.models.persona_image import PersonaImage
from app.services import cloudinary_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["admin"])


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


@router.get("/overview")
async def overview(db: AsyncSession = Depends(get_db)):
    total_users = (await db.execute(select(func.count(User.id)))).scalar_one()
    total_personas = (await db.execute(select(func.count(Persona.id)))).scalar_one()
    total_jobs = (await db.execute(select(func.count(GenerationJob.id)))).scalar_one()
    total_images = (await db.execute(select(func.count(GeneratedImage.id)))).scalar_one()

    persona_by_status = (
        await db.execute(
            select(Persona.status, func.count(Persona.id)).group_by(Persona.status)
        )
    ).all()

    job_by_status = (
        await db.execute(
            select(GenerationJob.status, func.count(GenerationJob.id)).group_by(GenerationJob.status)
        )
    ).all()

    return {
        "total_users": total_users,
        "total_personas": total_personas,
        "total_jobs": total_jobs,
        "total_generated_images": total_images,
        "personas_by_status": {row[0]: row[1] for row in persona_by_status},
        "jobs_by_status": {row[0]: row[1] for row in job_by_status},
    }


@router.get("/users")
async def list_users(
    page: int = 1,
    per_page: int = 50,
    db: AsyncSession = Depends(get_db),
):
    offset = (page - 1) * per_page
    result = await db.execute(
        select(User).order_by(User.created_at.desc()).offset(offset).limit(per_page)
    )
    users = result.scalars().all()

    total = (await db.execute(select(func.count(User.id)))).scalar_one()

    rows = []
    for u in users:
        persona_count = (
            await db.execute(select(func.count(Persona.id)).where(Persona.user_id == u.id))
        ).scalar_one()
        rows.append({
            "id": u.id,
            "device_id": u.device_id,
            "cloudkit_record_id": u.cloudkit_record_id,
            "persona_count": persona_count,
            "created_at": u.created_at.isoformat() if u.created_at else None,
        })

    return {"total": total, "page": page, "per_page": per_page, "users": rows}


@router.get("/personas")
async def list_personas(
    page: int = 1,
    per_page: int = 50,
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    offset = (page - 1) * per_page
    q = select(Persona).order_by(Persona.created_at.desc())
    count_q = select(func.count(Persona.id))
    if status:
        try:
            s = PersonaStatus(status)
            q = q.where(Persona.status == s)
            count_q = count_q.where(Persona.status == s)
        except ValueError:
            pass

    result = await db.execute(q.offset(offset).limit(per_page))
    personas = result.scalars().all()
    total = (await db.execute(count_q)).scalar_one()

    rows = []
    for p in personas:
        img_count = (
            await db.execute(select(func.count(PersonaImage.id)).where(PersonaImage.persona_id == p.id))
        ).scalar_one()
        job_count = (
            await db.execute(select(func.count(GenerationJob.id)).where(GenerationJob.persona_id == p.id))
        ).scalar_one()
        rows.append({
            "id": p.id,
            "name": p.name,
            "status": p.status,
            "subject_keyword": p.subject_keyword,
            "astria_tune_id": p.astria_tune_id,
            "cover_image_url": p.cover_image_url,
            "uploaded_image_count": img_count,
            "generation_job_count": job_count,
            "user_id": p.user_id,
            "created_at": p.created_at.isoformat() if p.created_at else None,
        })

    return {"total": total, "page": page, "per_page": per_page, "personas": rows}


@router.get("/jobs")
async def list_jobs(
    page: int = 1,
    per_page: int = 50,
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    offset = (page - 1) * per_page
    q = select(GenerationJob).order_by(GenerationJob.created_at.desc())
    count_q = select(func.count(GenerationJob.id))
    if status:
        try:
            s = GenerationStatus(status)
            q = q.where(GenerationJob.status == s)
            count_q = count_q.where(GenerationJob.status == s)
        except ValueError:
            pass

    result = await db.execute(q.offset(offset).limit(per_page))
    jobs = result.scalars().all()
    total = (await db.execute(count_q)).scalar_one()

    rows = []
    for j in jobs:
        images_result = await db.execute(
            select(GeneratedImage).where(GeneratedImage.job_id == j.id)
        )
        images = images_result.scalars().all()

        style = (await db.execute(select(StyleBundle).where(StyleBundle.id == j.style_bundle_id))).scalar_one_or_none()

        rows.append({
            "id": j.id,
            "status": j.status,
            "persona_id": j.persona_id,
            "style_bundle_id": j.style_bundle_id,
            "style_bundle_name": style.name if style else None,
            "user_id": j.user_id,
            "astria_prompt_id": j.astria_prompt_id,
            "error_message": j.error_message,
            "image_count": len(images),
            "images": [{"id": img.id, "url": img.image_url} for img in images],
            "created_at": j.created_at.isoformat() if j.created_at else None,
            "completed_at": j.completed_at.isoformat() if j.completed_at else None,
        })

    return {"total": total, "page": page, "per_page": per_page, "jobs": rows}


@router.get("/styles")
async def list_styles(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(StyleBundle).order_by(StyleBundle.sort_order))
    bundles = result.scalars().all()
    return [_bundle_dict(b) for b in bundles]


class StyleBundleUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[str] = None
    old_price: Optional[str] = None
    preview_image_url: Optional[str] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


@router.patch("/styles/by-product/{product_id}")
async def update_style_by_product(
    product_id: str,
    body: StyleBundleUpdate,
    db: AsyncSession = Depends(get_db),
):
    bundle = (await db.execute(select(StyleBundle).where(StyleBundle.product_id == product_id))).scalar_one_or_none()
    if not bundle:
        raise HTTPException(status_code=404, detail="Style bundle not found")
    return await _apply_update(bundle, body, db)


@router.patch("/styles/{bundle_id}")
async def update_style(
    bundle_id: str,
    body: StyleBundleUpdate,
    db: AsyncSession = Depends(get_db),
):
    bundle = (await db.execute(select(StyleBundle).where(StyleBundle.id == bundle_id))).scalar_one_or_none()
    if not bundle:
        raise HTTPException(status_code=404, detail="Style bundle not found")

    return await _apply_update(bundle, body, db)


async def _apply_update(bundle: StyleBundle, body: StyleBundleUpdate, db: AsyncSession):
    if body.name is not None:
        bundle.name = body.name
    if body.description is not None:
        bundle.description = body.description
    if body.price is not None:
        bundle.price = body.price
    if body.old_price is not None:
        bundle.old_price = body.old_price
    if body.preview_image_url is not None:
        bundle.preview_image_url = body.preview_image_url
    if body.is_active is not None:
        bundle.is_active = body.is_active
    if body.sort_order is not None:
        bundle.sort_order = body.sort_order

    await db.commit()
    await db.refresh(bundle)
    return _bundle_dict(bundle)


@router.post("/jobs/retry-failed")
async def retry_all_failed_jobs(db: AsyncSession = Depends(get_db)):
    """Reset all failed generation jobs back to queued so the worker retries them."""
    result = await db.execute(
        select(GenerationJob).where(GenerationJob.status == GenerationStatus.failed)
    )
    jobs = result.scalars().all()
    for job in jobs:
        job.status = GenerationStatus.queued
        job.error_message = None
        job.astria_prompt_id = None
    await db.commit()
    return {"retried": len(jobs), "message": f"{len(jobs)} job(s) queued for retry"}


@router.post("/jobs/{job_id}/retry")
async def retry_job(job_id: str, db: AsyncSession = Depends(get_db)):
    """Reset a single failed generation job back to queued."""
    job = (await db.execute(select(GenerationJob).where(GenerationJob.id == job_id))).scalar_one_or_none()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if job.status != GenerationStatus.failed:
        raise HTTPException(status_code=400, detail=f"Job is '{job.status}', not failed")
    job.status = GenerationStatus.queued
    job.error_message = None
    job.astria_prompt_id = None
    await db.commit()
    return {"message": "Job queued for retry", "job_id": job_id}


@router.post("/upload-image")
async def upload_image(file: UploadFile = File(...)):
    """Upload an image to Cloudinary and return its URL. Used by the admin panel."""
    data = await file.read()
    result = await asyncio.to_thread(
        cloudinary_service.upload_bytes,
        data,
        folder="sellface/admin/previews",
    )
    return {"url": result["url"]}


def _bundle_dict(b: StyleBundle) -> dict:
    return {
        "id": b.id,
        "name": b.name,
        "description": b.description,
        "product_id": b.product_id,
        "price": b.price,
        "old_price": b.old_price,
        "preview_image_url": b.preview_image_url,
        "preview_image_name": b.preview_image_name,
        "is_active": b.is_active,
        "sort_order": b.sort_order,
    }
