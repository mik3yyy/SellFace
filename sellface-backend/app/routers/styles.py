from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.style_bundle import StyleBundle
from app.schemas.style_bundle import StyleBundleOut

router = APIRouter(prefix="/styles", tags=["styles"])


@router.get("", response_model=list[StyleBundleOut])
async def list_styles(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(StyleBundle)
        .where(StyleBundle.is_active == True)
        .order_by(StyleBundle.sort_order, StyleBundle.name)
    )
    return [StyleBundleOut.model_validate(s) for s in result.scalars().all()]
