import enum
import uuid
from sqlalchemy import String, DateTime, ForeignKey, func, Enum, Text, BigInteger
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class GenerationStatus(str, enum.Enum):
    queued = "queued"
    processing = "processing"
    completed = "completed"
    failed = "failed"


class GenerationJob(Base):
    __tablename__ = "generation_jobs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    persona_id: Mapped[str] = mapped_column(String(36), ForeignKey("personas.id", ondelete="CASCADE"), nullable=False, index=True)
    style_bundle_id: Mapped[str] = mapped_column(String(36), ForeignKey("style_bundles.id"), nullable=False)
    celery_task_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Astria IDs — set once the API calls are made
    astria_prompt_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)

    status: Mapped[GenerationStatus] = mapped_column(Enum(GenerationStatus), default=GenerationStatus.queued, nullable=False)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    completed_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="generation_jobs")
    persona: Mapped["Persona"] = relationship("Persona", back_populates="generation_jobs")
    style_bundle: Mapped["StyleBundle"] = relationship("StyleBundle", back_populates="generation_jobs")
    generated_images: Mapped[list["GeneratedImage"]] = relationship("GeneratedImage", back_populates="job", cascade="all, delete-orphan")
