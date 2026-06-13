import logging
from typing import Optional
from fastapi import APIRouter
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/analytics", tags=["analytics"])


class EventRequest(BaseModel):
    user_id: Optional[str] = None
    event: str
    properties: Optional[dict] = None


@router.post("/event", status_code=200)
async def track_event(body: EventRequest):
    props = body.properties or {}
    prop_str = " ".join(f"{k}={v}" for k, v in props.items())
    logger.info("FUNNEL user=%s event=%s %s", body.user_id or "unknown", body.event, prop_str)
    return {"ok": True}
