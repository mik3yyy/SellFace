"""Add images_target to generation_jobs

Revision ID: 005
Revises: 004
Create Date: 2026-05-29
"""
from alembic import op
import sqlalchemy as sa

revision = "005"
down_revision = "004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("generation_jobs", sa.Column("images_target", sa.Integer(), nullable=False, server_default="8"))


def downgrade() -> None:
    op.drop_column("generation_jobs", "images_target")
