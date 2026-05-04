import uuid
from sqlalchemy import String, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class PersonaImage(Base):
    __tablename__ = "persona_images"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    persona_id: Mapped[str] = mapped_column(String(36), ForeignKey("personas.id", ondelete="CASCADE"), nullable=False, index=True)
    remote_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    cloudinary_public_id: Mapped[str | None] = mapped_column(String(512), nullable=True)
    uploaded_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    persona: Mapped["Persona"] = relationship("Persona", back_populates="images")
