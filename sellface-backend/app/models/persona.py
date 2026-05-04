import enum
import uuid
from sqlalchemy import String, DateTime, ForeignKey, func, Enum, BigInteger
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class PersonaStatus(str, enum.Enum):
    draft = "draft"
    uploading = "uploading"
    processing = "processing"   # Astria training in progress
    ready = "ready"             # Astria training done — ready to generate
    failed = "failed"


class Persona(Base):
    __tablename__ = "personas"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    subject_keyword: Mapped[str] = mapped_column(String(50), nullable=False, default="man")  # "man" | "woman" | "person"
    status: Mapped[PersonaStatus] = mapped_column(Enum(PersonaStatus), default=PersonaStatus.draft, nullable=False)
    cover_image_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)

    # Astria fine-tune ID — set after training is submitted
    astria_tune_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)

    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user: Mapped["User"] = relationship("User", back_populates="personas")
    images: Mapped[list["PersonaImage"]] = relationship("PersonaImage", back_populates="persona", cascade="all, delete-orphan")
    generation_jobs: Mapped[list["GenerationJob"]] = relationship("GenerationJob", back_populates="persona")
