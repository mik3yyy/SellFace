from sqlalchemy import String, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
import uuid


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    cloudkit_record_id: Mapped[str | None] = mapped_column(String(255), unique=True, index=True, nullable=True)
    device_id: Mapped[str | None] = mapped_column(String(255), unique=True, index=True, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    personas: Mapped[list["Persona"]] = relationship("Persona", back_populates="user", cascade="all, delete-orphan")
    generation_jobs: Mapped[list["GenerationJob"]] = relationship("GenerationJob", back_populates="user")
    device_tokens: Mapped[list["DeviceToken"]] = relationship("DeviceToken", back_populates="user", cascade="all, delete-orphan")
