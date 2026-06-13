"""
User account management endpoints.

DELETE /me — deletes the calling user's account and all associated data
(personas, images, generation jobs, device tokens). Satisfies App Store
Guideline 5.1.1(viii) requiring an in-app account deletion mechanism.
"""
import logging

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.persona import Persona
from app.models.persona_image import PersonaImage
from app.models.generation_job import GenerationJob
from app.models.generated_image import GeneratedImage
from app.models.device_token import DeviceToken

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/users", tags=["users"])


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Permanently delete the authenticated user's account and all data.
    Cascades: device tokens, generation jobs/images, persona images, personas, then the user row.
    """
    user_id = user.id
    logger.info("Account deletion requested for user %s", user_id)

    # Collect persona IDs owned by this user
    persona_ids_result = await db.execute(
        select(Persona.id).where(Persona.user_id == user_id)
    )
    persona_ids = [r for r in persona_ids_result.scalars().all()]

    # Collect job IDs for those personas (needed to delete generated images)
    if persona_ids:
        job_ids_result = await db.execute(
            select(GenerationJob.id).where(GenerationJob.persona_id.in_(persona_ids))
        )
        job_ids = [r for r in job_ids_result.scalars().all()]

        # Delete generated images
        if job_ids:
            await db.execute(delete(GeneratedImage).where(GeneratedImage.job_id.in_(job_ids)))

        # Delete persona images
        await db.execute(delete(PersonaImage).where(PersonaImage.persona_id.in_(persona_ids)))

        # Delete generation jobs
        await db.execute(delete(GenerationJob).where(GenerationJob.persona_id.in_(persona_ids)))

        # Delete personas
        await db.execute(delete(Persona).where(Persona.user_id == user_id))

    # Delete device tokens
    await db.execute(delete(DeviceToken).where(DeviceToken.user_id == user_id))

    # Delete the user row itself
    await db.execute(delete(User).where(User.id == user_id))

    await db.commit()
    logger.info("Account and all data deleted for user %s", user_id)
