"""Update style bundles: remove sales, add corporate/golden hour/neon nights/academic

Revision ID: 004
Revises: 003
Create Date: 2026-05-28
"""
from alembic import op
import sqlalchemy as sa

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None

NEW_BUNDLES = [
    {
        "id": "corporate",
        "name": "corporate",
        "description": "Modern boardroom authority",
        "product_id": "com.sellface.style.corporate",
        "price": "9.99",
        "preview_image_name": "building.columns.fill",
        "sort_order": 8,
    },
    {
        "id": "goldenhour",
        "name": "golden hour",
        "description": "Warm golden lifestyle look",
        "product_id": "com.sellface.style.goldenhour",
        "price": "9.99",
        "preview_image_name": "sun.horizon.fill",
        "sort_order": 9,
    },
    {
        "id": "neonnights",
        "name": "neon nights",
        "description": "Bold neon editorial style",
        "product_id": "com.sellface.style.neonnights",
        "price": "9.99",
        "preview_image_name": "moon.stars.fill",
        "sort_order": 10,
    },
    {
        "id": "academic",
        "name": "academic",
        "description": "Refined intellectual portrait",
        "product_id": "com.sellface.style.academic",
        "price": "9.99",
        "preview_image_name": "graduationcap.fill",
        "sort_order": 11,
    },
]

REMOVED_IDS = ["sales"]


def upgrade() -> None:
    conn = op.get_bind()

    # Deactivate removed styles
    for bundle_id in REMOVED_IDS:
        conn.execute(
            sa.text("UPDATE style_bundles SET is_active = false WHERE id = :id"),
            {"id": bundle_id},
        )

    # Insert new styles
    for b in NEW_BUNDLES:
        conn.execute(
            sa.text(
                "INSERT INTO style_bundles "
                "(id, name, description, product_id, price, preview_image_name, is_active, sort_order) "
                "VALUES (:id, :name, :description, :product_id, :price, :preview_image_name, :is_active, :sort_order) "
                "ON CONFLICT (product_id) DO NOTHING"
            ),
            {**b, "is_active": True},
        )


def downgrade() -> None:
    conn = op.get_bind()

    # Remove new styles
    for b in NEW_BUNDLES:
        conn.execute(
            sa.text("DELETE FROM style_bundles WHERE id = :id"),
            {"id": b["id"]},
        )

    # Re-activate removed styles
    for bundle_id in REMOVED_IDS:
        conn.execute(
            sa.text("UPDATE style_bundles SET is_active = true WHERE id = :id"),
            {"id": bundle_id},
        )
