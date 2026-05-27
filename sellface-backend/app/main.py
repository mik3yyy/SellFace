import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
import os

from app.config import get_settings
from app.database import engine, AsyncSessionLocal
from app.routers import personas, generation_jobs, styles, devices, admin, webhooks

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)
settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("SellFace API starting up")
    # Seed style bundles on first run
    async with AsyncSessionLocal() as db:
        await seed_styles(db)
    yield
    await engine.dispose()
    logger.info("SellFace API shut down")


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Native iOS clients don't send CORS Origin headers, so this only affects
# browser-based access (Swagger UI, admin dashboard). Restrict in production
# by setting ALLOWED_ORIGINS in .env.
_allowed_origins = (
    ["*"] if settings.debug
    else ["https://sellface.app", "https://www.sellface.app"]
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(personas.router)
app.include_router(generation_jobs.router)
app.include_router(styles.router)
app.include_router(devices.router)
app.include_router(admin.router)
app.include_router(webhooks.router)

# Serve admin dashboard HTML
_static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.isdir(_static_dir):
    app.mount("/static", StaticFiles(directory=_static_dir), name="static")


@app.get("/admin", response_class=HTMLResponse, include_in_schema=False)
async def admin_dashboard():
    html_path = os.path.join(os.path.dirname(__file__), "static", "admin.html")
    with open(html_path) as f:
        return HTMLResponse(content=f.read())


@app.get("/health", tags=["health"])
async def health():
    async with AsyncSessionLocal() as db:
        await db.execute(text("SELECT 1"))
    return {"status": "ok", "version": "1.0.0"}


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled exception on %s %s", request.method, request.url)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"},
    )


# ── Seed data ──────────────────────────────────────────────────────────────────

async def seed_styles(db):
    from sqlalchemy import select
    from app.models.style_bundle import StyleBundle

    result = await db.execute(select(StyleBundle).limit(1))
    if result.scalar_one_or_none():
        return  # already seeded

    bundles = [
        dict(name="Professional", description="Sharp business headshots", product_id="com.sellface.style.professional", price="£2.99", old_price="£9.99", preview_image_name="briefcase.fill", sort_order=0),
        dict(name="Casual", description="Relaxed everyday looks", product_id="com.sellface.style.casual", price="£2.99", old_price="£9.99", preview_image_name="figure.walk", sort_order=1),
        dict(name="Executive", description="C-suite authority looks", product_id="com.sellface.style.executive", price="£2.99", old_price="£9.99", preview_image_name="star.fill", sort_order=2),
        dict(name="Creator", description="Standout creator content", product_id="com.sellface.style.creator", price="£2.99", old_price="£9.99", preview_image_name="video.fill", sort_order=3),
        dict(name="LinkedIn", description="Profile-ready portraits", product_id="com.sellface.style.linkedin", price="£2.99", old_price="£9.99", preview_image_name="person.crop.square.fill", sort_order=4),
        dict(name="Old Money", description="Classic aristocratic vibes", product_id="com.sellface.style.oldmoney", price="£2.99", old_price="£9.99", preview_image_name="crown.fill", sort_order=5),
        dict(name="Sales", description="High-trust, high-conversion", product_id="com.sellface.style.sales", price="£2.99", old_price="£9.99", preview_image_name="chart.line.uptrend.xyaxis", sort_order=6),
        dict(name="Studio", description="Premium studio lighting", product_id="com.sellface.style.studio", price="£2.99", old_price="£9.99", preview_image_name="camera.fill", sort_order=7),
    ]
    import uuid as _uuid
    for b in bundles:
        db.add(StyleBundle(id=str(_uuid.uuid4()), **b))
    await db.commit()
    logger.info("Seeded %d style bundles", len(bundles))
