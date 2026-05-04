from pydantic import BaseModel
from datetime import datetime


class StyleBundleOut(BaseModel):
    id: str
    name: str
    description: str
    product_id: str
    price: str
    old_price: str | None
    preview_image_url: str | None
    preview_image_name: str
    is_active: bool
    sort_order: int

    model_config = {"from_attributes": True}
