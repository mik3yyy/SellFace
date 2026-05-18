"""Seed style_bundles table

Revision ID: 003
Revises: 002
Create Date: 2026-05-18
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.sql import table, column

revision = "003"
down_revision = "002"
branch_labels = None
depends_on = None

# IDs must match iOS StyleBundle.staticMetadata id values so the iOS
# `bundle.id` lookup hits the right row.
# `name` must match the STYLE_PROMPTS keys in astria_service.py
#   (lowercased) so Astria gets the right prompt.
STYLE_BUNDLES = [
    {
        "id": "professional",
        "name": "professional",
        "description": "Sharp business headshots",
        "product_id": "com.sellface.style.professional",
        "price": "9.99",
        "preview_image_name": "briefcase.fill",
        "sort_order": 0,
    },
    {
        "id": "casual",
        "name": "casual",
        "description": "Relaxed everyday looks",
        "product_id": "com.sellface.style.casual",
        "price": "9.99",
        "preview_image_name": "figure.walk",
        "sort_order": 1,
    },
    {
        "id": "executive",
        "name": "executive",
        "description": "C-suite authority looks",
        "product_id": "com.sellface.style.executive",
        "price": "9.99",
        "preview_image_name": "star.fill",
        "sort_order": 2,
    },
    {
        "id": "creator",
        "name": "creator",
        "description": "Standout creator content",
        "product_id": "com.sellface.style.creator",
        "price": "9.99",
        "preview_image_name": "video.fill",
        "sort_order": 3,
    },
    {
        "id": "linkedin",
        "name": "linkedin",
        "description": "Profile-ready portraits",
        "product_id": "com.sellface.style.linkedin",
        "price": "9.99",
        "preview_image_name": "person.crop.square.fill",
        "sort_order": 4,
    },
    {
        "id": "oldmoney",
        # name must match STYLE_PROMPTS key "old money" in astria_service.py
        "name": "old money",
        "description": "Classic aristocratic vibes",
        "product_id": "com.sellface.style.oldmoney",
        "price": "9.99",
        "preview_image_name": "crown.fill",
        "sort_order": 5,
    },
    {
        "id": "sales",
        "name": "sales",
        "description": "High-trust, high-conversion",
        "product_id": "com.sellface.style.sales",
        "price": "9.99",
        "preview_image_name": "chart.line.uptrend.xyaxis",
        "sort_order": 6,
    },
    {
        "id": "studio",
        "name": "studio",
        "description": "Premium studio lighting",
        "product_id": "com.sellface.style.studio",
        "price": "9.99",
        "preview_image_name": "camera.fill",
        "sort_order": 7,
    },
]

style_bundles_table = table(
    "style_bundles",
    column("id", sa.String),
    column("name", sa.String),
    column("description", sa.String),
    column("product_id", sa.String),
    column("price", sa.String),
    column("preview_image_name", sa.String),
    column("is_active", sa.Boolean),
    column("sort_order", sa.Integer),
)


def upgrade() -> None:
    conn = op.get_bind()
    for b in STYLE_BUNDLES:
        conn.execute(
            sa.text(
                "INSERT INTO style_bundles (id, name, description, product_id, price, preview_image_name, is_active, sort_order) "
                "VALUES (:id, :name, :description, :product_id, :price, :preview_image_name, :is_active, :sort_order) "
                "ON CONFLICT (product_id) DO UPDATE SET id = :id, name = :name"
            ),
            {**b, "is_active": True},
        )


def downgrade() -> None:
    op.execute(
        "DELETE FROM style_bundles WHERE id IN ({})".format(
            ", ".join(f"'{b['id']}'" for b in STYLE_BUNDLES)
        )
    )
