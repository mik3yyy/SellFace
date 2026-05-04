from pydantic import BaseModel, Field
from datetime import datetime
from typing import Literal
from app.models.persona import PersonaStatus


class PersonaCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    subject_keyword: Literal["man", "woman", "person"] = "man"


class PersonaUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=255)
    status: PersonaStatus | None = None


class PersonaImageOut(BaseModel):
    id: str
    persona_id: str
    remote_url: str | None
    uploaded_at: datetime

    model_config = {"from_attributes": True}


class PersonaOut(BaseModel):
    id: str
    user_id: str
    name: str
    subject_keyword: str
    status: PersonaStatus
    cover_image_url: str | None
    astria_tune_id: int | None
    created_at: datetime
    updated_at: datetime
    image_count: int = 0

    model_config = {"from_attributes": True}


class PersonaDetailOut(PersonaOut):
    images: list[PersonaImageOut] = []
