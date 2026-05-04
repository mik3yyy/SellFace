import uuid
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.device_token import DeviceToken
from app.schemas.common import DeviceTokenIn, MessageOut

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register-token", response_model=MessageOut, status_code=status.HTTP_200_OK)
async def register_device_token(
    body: DeviceTokenIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Upsert: find existing token or create
    result = await db.execute(
        select(DeviceToken).where(DeviceToken.token == body.token)
    )
    token_row = result.scalar_one_or_none()
    if token_row:
        token_row.user_id = user.id
        token_row.is_active = True
        token_row.platform = body.platform
    else:
        token_row = DeviceToken(
            id=str(uuid.uuid4()),
            user_id=user.id,
            token=body.token,
            platform=body.platform,
        )
        db.add(token_row)

    await db.commit()
    return MessageOut(message="Device token registered")
