"""
Cloudinary service for image upload and management.
All methods are synchronous so they work from both FastAPI (via executor) and Celery.
"""
import io
import logging
import cloudinary
import cloudinary.uploader
from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def _configure():
    cloudinary.config(
        cloud_name=settings.cloudinary_cloud_name,
        api_key=settings.cloudinary_api_key,
        api_secret=settings.cloudinary_api_secret,
        secure=True,
    )


def upload_bytes(data: bytes, folder: str, public_id: str | None = None) -> dict:
    """Upload raw bytes. Returns Cloudinary response dict with 'secure_url' and 'public_id'."""
    _configure()
    try:
        response = cloudinary.uploader.upload(
            io.BytesIO(data),
            folder=folder,
            public_id=public_id,
            overwrite=True,
            resource_type="image",
        )
        return {"url": response["secure_url"], "public_id": response["public_id"]}
    except Exception as e:
        logger.error("Cloudinary upload failed: %s", e)
        raise


def upload_url(image_url: str, folder: str) -> dict:
    """Upload from a remote URL. Useful for AI-generated images."""
    _configure()
    try:
        response = cloudinary.uploader.upload(
            image_url,
            folder=folder,
            resource_type="image",
        )
        return {"url": response["secure_url"], "public_id": response["public_id"]}
    except Exception as e:
        logger.error("Cloudinary URL upload failed: %s", e)
        raise


def delete_image(public_id: str) -> None:
    _configure()
    try:
        cloudinary.uploader.destroy(public_id)
    except Exception as e:
        logger.warning("Cloudinary delete failed for %s: %s", public_id, e)
