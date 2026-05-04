import uuid
from sqlalchemy import String, Boolean, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class StyleBundle(Base):
    __tablename__ = "style_bundles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(String(1024), nullable=False)
    product_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    price: Mapped[str] = mapped_column(String(50), nullable=False)
    old_price: Mapped[str | None] = mapped_column(String(50), nullable=True)
    preview_image_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    preview_image_name: Mapped[str] = mapped_column(String(255), nullable=False, default="photo.fill")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    sort_order: Mapped[int] = mapped_column(default=0, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    generation_jobs: Mapped[list["GenerationJob"]] = relationship("GenerationJob", back_populates="style_bundle")
