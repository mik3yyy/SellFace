"""
Astria.ai API client.

Flow per persona:
  1. create_tune()     → trains a personal LoRA model on the user's face photos
  2. get_tune()        → poll until trained_at is set (~20 min for Flux, ~5 min for SDXL)
  3. create_prompts()  → generates images using the trained model + style prompts
  4. get_prompt()      → poll until images[] is populated

All methods are synchronous — designed to run inside Celery tasks.
"""
import logging
import time
import requests
from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# ── Style prompt library ───────────────────────────────────────────────────────
# {kw} is replaced with "ohwx man" / "ohwx woman" / "ohwx person"
STYLE_PROMPTS: dict[str, tuple[str, str]] = {
    # (positive_prompt, negative_prompt)
    "professional": (
        "professional corporate headshot of {kw}, tailored business suit, white studio background, "
        "soft box lighting, sharp focus, 4k, photorealistic, LinkedIn profile photo",
        "blurry, low quality, cartoon, painting, deformed, bad anatomy, ugly, sunglasses, hat",
    ),
    "casual": (
        "casual lifestyle portrait of {kw}, relaxed natural smile, outdoors in a park, "
        "golden hour lighting, bokeh background, wearing jeans and a t-shirt, photorealistic",
        "blurry, low quality, formal, suit, deformed, bad anatomy, ugly",
    ),
    "executive": (
        "executive C-suite portrait of {kw}, power pose, expensive Italian suit, "
        "luxury modern boardroom background, dramatic Rembrandt lighting, confident expression, "
        "4k photorealistic, editorial photography",
        "blurry, low quality, casual, deformed, bad anatomy, ugly, cartoon",
    ),
    "creator": (
        "social media content creator portrait of {kw}, vibrant colorful background, "
        "trendy streetwear outfit, ring light catchlights, energetic expression, "
        "Instagram aesthetic, photorealistic",
        "blurry, low quality, formal, suit, deformed, bad anatomy, ugly",
    ),
    "linkedin": (
        "LinkedIn profile photo of {kw}, warm professional smile, smart business casual, "
        "clean light grey background, soft studio lighting, trustworthy and approachable, "
        "photorealistic, headshot",
        "blurry, low quality, casual, deformed, bad anatomy, ugly, sunglasses",
    ),
    "old money": (
        "old money aristocratic portrait of {kw}, wearing heritage tweed blazer, "
        "English country estate background, oil painting lighting, sophisticated elegant posture, "
        "photorealistic, painterly",
        "blurry, low quality, modern, streetwear, deformed, bad anatomy, ugly",
    ),
    "sales": (
        "high-trust sales professional portrait of {kw}, warm confident smile, "
        "business casual attire, modern glass office background, "
        "approachable and credible expression, photorealistic",
        "blurry, low quality, deformed, bad anatomy, ugly, sunglasses",
    ),
    "studio": (
        "premium studio portrait of {kw}, dramatic chiaroscuro lighting, "
        "pure black background, high contrast, deep shadows, editorial magazine photography, "
        "4k, photorealistic",
        "blurry, low quality, outdoor, colorful, deformed, bad anatomy, ugly",
    ),
}

NEGATIVE_DEFAULT = "blurry, lowres, bad anatomy, bad hands, extra fingers, deformed, ugly, cartoon, anime, watermark, text"


def _headers() -> dict:
    if not settings.astria_api_key:
        raise RuntimeError("ASTRIA_API_KEY is not set in environment")
    return {"Authorization": f"Bearer {settings.astria_api_key}"}


def _url(path: str) -> str:
    return f"{settings.astria_base_url}{path}"


# ── Tune (training) ────────────────────────────────────────────────────────────

def create_tune(title: str, image_urls: list[str], subject_keyword: str = "man") -> dict:
    """
    Submit a fine-tuning job to Astria.

    Returns the full tune dict including `id` (integer).
    Training takes ~20 minutes (Flux) or ~5 minutes (SDXL).
    """
    if not image_urls:
        raise ValueError("At least one image URL is required to create a tune")

    data = {
        "tune[title]": title,
        "tune[name]": subject_keyword,       # "man" | "woman" | "person"
        "tune[branch]": settings.astria_branch,
        "tune[callback]": "",                 # no webhook — we poll
    }
    # Astria expects repeated keys for arrays
    for url in image_urls:
        data.setdefault("tune[image_urls][]", [])
        if isinstance(data["tune[image_urls][]"], list):
            data["tune[image_urls][]"].append(url)
        else:
            data["tune[image_urls][]"] = [data["tune[image_urls][]"], url]

    logger.info("Creating Astria tune for '%s' with %d images (branch=%s)", title, len(image_urls), settings.astria_branch)
    response = requests.post(
        _url("/tunes"),
        headers=_headers(),
        data=data,
        timeout=30,
    )
    _raise_for_status(response)
    tune = response.json()
    logger.info("Astria tune created: id=%s", tune["id"])
    return tune


def get_tune(tune_id: int) -> dict:
    """Fetch current tune state. `trained_at` is set when training is complete."""
    response = requests.get(_url(f"/tunes/{tune_id}"), headers=_headers(), timeout=15)
    _raise_for_status(response)
    return response.json()


def is_tune_ready(tune: dict) -> bool:
    return tune.get("trained_at") is not None


def is_tune_failed(tune: dict) -> bool:
    return tune.get("error") is not None


# ── Prompts (generation) ───────────────────────────────────────────────────────

def create_prompts(tune_id: int, style_name: str, subject_keyword: str = "man") -> dict:
    """
    Submit a generation prompt to an already-trained tune.

    Returns the prompt dict including `id`.
    Images fill in asynchronously — poll get_prompt() until `images` is non-empty.
    """
    trigger = f"ohwx {subject_keyword}"
    style_key = style_name.lower().strip()
    positive, negative = STYLE_PROMPTS.get(style_key, (
        f"professional portrait of {trigger}, photorealistic, high quality",
        NEGATIVE_DEFAULT,
    ))
    positive = positive.replace("{kw}", trigger)

    payload = {
        "prompt": {
            "text": positive,
            "negative_prompt": negative,
            "num_images": settings.astria_images_per_job,
            "w": 768,
            "h": 1024,
            "steps": 30,
            "cfg_scale": 7.5,
            "callback": "",
        }
    }
    logger.info("Creating Astria prompt for tune %s | style=%s", tune_id, style_name)
    response = requests.post(
        _url(f"/tunes/{tune_id}/prompts"),
        headers=_headers(),
        json=payload,
        timeout=30,
    )
    _raise_for_status(response)
    prompt = response.json()
    logger.info("Astria prompt created: id=%s", prompt["id"])
    return prompt


def get_prompt(tune_id: int, prompt_id: int) -> dict:
    """Fetch current prompt state. `images` is populated when generation is complete."""
    response = requests.get(
        _url(f"/tunes/{tune_id}/prompts/{prompt_id}"),
        headers=_headers(),
        timeout=15,
    )
    _raise_for_status(response)
    return response.json()


def are_images_ready(prompt: dict) -> bool:
    return bool(prompt.get("images"))


def download_image(url: str) -> bytes:
    """Download a generated image from Astria CDN."""
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    return response.content


# ── Helpers ────────────────────────────────────────────────────────────────────

def _raise_for_status(response: requests.Response) -> None:
    if not response.ok:
        body = response.text[:500]
        logger.error("Astria API error %d: %s", response.status_code, body)
        raise AstriaAPIError(response.status_code, body)


class AstriaAPIError(Exception):
    def __init__(self, status_code: int, body: str):
        self.status_code = status_code
        self.body = body
        super().__init__(f"Astria API {status_code}: {body}")
