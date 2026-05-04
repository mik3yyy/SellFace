import uuid
from sqlalchemy import String, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class GeneratedImage(Base):
    __tablename__ = "generated_images"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    job_id: Mapped[str] = mapped_column(String(36), ForeignKey("generation_jobs.id", ondelete="CASCADE"), nullable=False, index=True)
    image_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    cloudinary_public_id: Mapped[str | None] = mapped_column(String(512), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    job: Mapped["GenerationJob"] = relationship("GenerationJob", back_populates="generated_images")
