"""Add Astria fields to personas and generation_jobs

Revision ID: 002
Revises: 001
Create Date: 2026-05-03
"""
from alembic import op
import sqlalchemy as sa

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("personas", sa.Column("astria_tune_id", sa.BigInteger(), nullable=True))
    op.add_column("personas", sa.Column("subject_keyword", sa.String(50), nullable=False, server_default="man"))
    op.add_column("generation_jobs", sa.Column("astria_prompt_id", sa.BigInteger(), nullable=True))


def downgrade() -> None:
    op.drop_column("personas", "astria_tune_id")
    op.drop_column("personas", "subject_keyword")
    op.drop_column("generation_jobs", "astria_prompt_id")
