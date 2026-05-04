"""Initial schema

Revision ID: 001
Revises:
Create Date: 2026-05-03
"""
from alembic import op
import sqlalchemy as sa

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("cloudkit_record_id", sa.String(255), unique=True, nullable=True),
        sa.Column("device_id", sa.String(255), unique=True, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_users_cloudkit_record_id", "users", ["cloudkit_record_id"])
    op.create_index("ix_users_device_id", "users", ["device_id"])

    op.create_table(
        "personas",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("status", sa.Enum("draft", "uploading", "processing", "ready", "failed", name="personastatus"), nullable=False, server_default="draft"),
        sa.Column("cover_image_url", sa.String(1024), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_personas_user_id", "personas", ["user_id"])

    op.create_table(
        "persona_images",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("persona_id", sa.String(36), sa.ForeignKey("personas.id", ondelete="CASCADE"), nullable=False),
        sa.Column("remote_url", sa.String(1024), nullable=True),
        sa.Column("cloudinary_public_id", sa.String(512), nullable=True),
        sa.Column("uploaded_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_persona_images_persona_id", "persona_images", ["persona_id"])

    op.create_table(
        "style_bundles",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.String(1024), nullable=False),
        sa.Column("product_id", sa.String(255), unique=True, nullable=False),
        sa.Column("price", sa.String(50), nullable=False),
        sa.Column("old_price", sa.String(50), nullable=True),
        sa.Column("preview_image_url", sa.String(1024), nullable=True),
        sa.Column("preview_image_name", sa.String(255), nullable=False, server_default="photo.fill"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "generation_jobs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("persona_id", sa.String(36), sa.ForeignKey("personas.id", ondelete="CASCADE"), nullable=False),
        sa.Column("style_bundle_id", sa.String(36), sa.ForeignKey("style_bundles.id"), nullable=False),
        sa.Column("celery_task_id", sa.String(255), nullable=True),
        sa.Column("status", sa.Enum("queued", "processing", "completed", "failed", name="generationstatus"), nullable=False, server_default="queued"),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_generation_jobs_user_id", "generation_jobs", ["user_id"])
    op.create_index("ix_generation_jobs_persona_id", "generation_jobs", ["persona_id"])

    op.create_table(
        "generated_images",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("job_id", sa.String(36), sa.ForeignKey("generation_jobs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("image_url", sa.String(1024), nullable=False),
        sa.Column("cloudinary_public_id", sa.String(512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_generated_images_job_id", "generated_images", ["job_id"])

    op.create_table(
        "device_tokens",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token", sa.String(512), unique=True, nullable=False),
        sa.Column("platform", sa.String(50), nullable=False, server_default="ios"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_device_tokens_user_id", "device_tokens", ["user_id"])


def downgrade() -> None:
    op.drop_table("device_tokens")
    op.drop_table("generated_images")
    op.drop_table("generation_jobs")
    op.drop_table("style_bundles")
    op.drop_table("persona_images")
    op.drop_table("personas")
    op.drop_table("users")
    op.execute("DROP TYPE IF EXISTS personastatus")
    op.execute("DROP TYPE IF EXISTS generationstatus")
