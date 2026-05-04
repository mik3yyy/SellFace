from pydantic import BaseModel, Field
from datetime import datetime
from app.models.generation_job import GenerationStatus


class GenerationJobCreate(BaseModel):
    persona_id: str = Field(..., min_length=1)
    style_bundle_id: str = Field(..., min_length=1)


class GeneratedImageOut(BaseModel):
    id: str
    job_id: str
    image_url: str
    created_at: datetime

    model_config = {"from_attributes": True}


class GenerationJobOut(BaseModel):
    id: str
    user_id: str
    persona_id: str
    style_bundle_id: str
    status: GenerationStatus
    error_message: str | None
    created_at: datetime
    completed_at: datetime | None

    model_config = {"from_attributes": True}


class GenerationJobDetailOut(GenerationJobOut):
    generated_images: list[GeneratedImageOut] = []
