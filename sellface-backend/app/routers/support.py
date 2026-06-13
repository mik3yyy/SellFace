import asyncio
import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr, field_validator

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/support", tags=["support"])


class ContactRequest(BaseModel):
    name: str
    email: EmailStr
    subject: str
    message: str

    @field_validator("name", "subject", "message")
    @classmethod
    def not_empty(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Field cannot be empty")
        return v.strip()

    @field_validator("message")
    @classmethod
    def message_min_length(cls, v: str) -> str:
        if len(v) < 10:
            raise ValueError("Message must be at least 10 characters")
        return v


@router.post("/contact")
async def contact(body: ContactRequest):
    from app.services.email_service import send_support_request
    await asyncio.to_thread(
        send_support_request,
        name=body.name,
        email=body.email,
        subject=body.subject,
        message=body.message,
    )
    return {"success": True}
