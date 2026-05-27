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
        "professional corporate headshot photograph of {kw}, wearing a sharply tailored charcoal or navy business suit "
        "with a crisp white dress shirt and subtle tie, confident neutral expression with direct eye contact, "
        "clean light grey or white seamless studio backdrop, three-point soft box lighting with a hair light creating "
        "a subtle rim on the shoulders, catch lights in both eyes, shallow depth of field with crisp focus on the eyes "
        "and face, 85mm portrait lens, skin retouched but natural-looking, photorealistic DSLR quality, "
        "suitable for Fortune 500 company website or board of directors page, 4K ultra sharp",
        "blurry, out of focus, low quality, cartoon, painting, illustration, deformed face, bad anatomy, "
        "extra fingers, sunglasses, hat, cap, casual clothing, t-shirt, hoodie, watermark, text, logo, "
        "oversaturated, HDR, dramatic shadows, smiling too wide, teeth showing unnaturally",
    ),
    "casual": (
        "candid lifestyle portrait photograph of {kw}, wearing a well-fitted casual smart outfit such as clean "
        "jeans, a fitted t-shirt or open collar shirt, relaxed and genuine warm smile, standing outdoors in a "
        "bright urban street or lush green park setting, soft natural golden hour sunlight creating warm skin tones "
        "and a creamy bokeh background with blurred greenery or architecture, slight head tilt showing personality, "
        "50mm lens at f/1.8, shallow depth of field, natural skin tones, photorealistic lifestyle photography, "
        "approachable and friendly energy, magazine editorial quality",
        "blurry, low quality, formal suit, tie, deformed face, bad anatomy, extra fingers, ugly, "
        "artificial lighting, studio background, stiff pose, watermark, text, overexposed, underexposed",
    ),
    "executive": (
        "high-end executive C-suite portrait photograph of {kw}, wearing a premium tailored Italian wool suit "
        "in deep charcoal or midnight blue with a luxury silk tie and white pocket square, polished cufflinks visible, "
        "commanding authoritative posture with arms crossed or hands clasped, sharp confident gaze projecting power "
        "and credibility, set in a sleek modern corporate boardroom with floor-to-ceiling glass windows and city skyline "
        "blurred behind, dramatic Rembrandt split lighting with strong key light and soft fill, subtle shadow on one side "
        "of the face adding depth and gravitas, 85mm lens, ultra-sharp focus on eyes, photorealistic editorial "
        "photography worthy of Forbes or Harvard Business Review cover, 4K",
        "blurry, low quality, casual, jeans, t-shirt, hoodie, deformed face, bad anatomy, extra fingers, "
        "cartoon, painting, watermark, text, smiling too much, overly cheerful, flat lighting, soft lighting, "
        "amateur photography, plastic skin",
    ),
    "creator": (
        "vibrant social media content creator portrait photograph of {kw}, wearing a stylish trendy streetwear outfit "
        "with bold colours — think oversized hoodie, graphic tee, or modern streetwear pieces with expressive accessories, "
        "energetic and charismatic expression with a confident engaging smile and direct eye contact, set against a "
        "vivid gradient or painted wall background in electric colours — neon purple, cobalt blue, or warm coral, "
        "professional ring light creating perfect circular catch lights in both eyes, subtle rim backlight for separation, "
        "35mm lens, vibrant punchy colour grading, high contrast lifestyle photography, TikTok and Instagram aesthetic, "
        "editorial influencer photography quality, sharp and dynamic",
        "blurry, low quality, formal, suit, tie, boring background, deformed face, bad anatomy, extra fingers, "
        "dull colours, flat lighting, stiff pose, watermark, text, overexposed, amateur",
    ),
    "linkedin": (
        "polished LinkedIn profile headshot photograph of {kw}, wearing smart business casual attire such as a "
        "well-fitted blazer over a collared shirt or blouse in muted professional tones — navy, grey, or white, "
        "warm genuine confident smile showing approachability and trustworthiness, direct friendly eye contact, "
        "set against a clean neutral light grey or soft white studio backdrop, even flattering two-point soft box "
        "studio lighting eliminating harsh shadows, subtle hair light for dimension, catch lights clearly visible "
        "in both eyes, 85mm portrait lens, sharp focus on the eyes and face, natural skin tones, professional "
        "headshot photographer quality, approachable credible and likeable, photorealistic 4K",
        "blurry, low quality, casual, t-shirt, deformed face, bad anatomy, extra fingers, sunglasses, hat, "
        "outdoor background, dramatic lighting, harsh shadows, watermark, text, overly serious, stern expression, "
        "too much retouching, plastic skin",
    ),
    "old money": (
        "distinguished old money aristocratic portrait photograph of {kw}, wearing a heritage Savile Row tailored "
        "tweed blazer or hacking jacket with a fine wool turtleneck or pressed Oxford shirt, a polished signet ring "
        "subtly visible, refined elegant posture exuding understated wealth and generational class, set in a timeless "
        "English countryside estate library or grand drawing room with rich wooden bookshelves, leather Chesterfield "
        "sofa, and Persian rugs softly blurred in the background, warm candlelit Rembrandt portrait lighting with "
        "a golden amber hue reminiscent of Old Master oil paintings, 85mm lens, shallow depth of field, film grain "
        "texture, painterly photorealistic quality, editorial luxury lifestyle photography",
        "blurry, low quality, modern streetwear, casual, sportswear, deformed face, bad anatomy, extra fingers, "
        "cartoon, anime, watermark, text, harsh flash, neon colours, contemporary office background",
    ),
    "sales": (
        "high-trust professional sales portrait photograph of {kw}, wearing a sharp business casual outfit such as "
        "a fitted blazer over a smart open-collar shirt in warm approachable tones — light blue, white, or soft grey, "
        "a broad natural confident smile showing genuine warmth and credibility, open and inviting body language with "
        "a slight forward lean conveying attentiveness, set in a bright modern glass-walled office with blurred "
        "contemporary workspace in the background, clean bright three-point studio lighting creating an optimistic "
        "and energetic feel, catch lights in both eyes, 85mm lens at f/2, shallow depth of field with tack-sharp "
        "face, warm natural skin tones, photorealistic professional headshot quality, the kind of photo that makes "
        "people immediately trust you and want to do business with you",
        "blurry, low quality, deformed face, bad anatomy, extra fingers, sunglasses, hat, harsh shadows, "
        "dark background, stern expression, crossed arms looking closed off, watermark, text, cartoon",
    ),
    "studio": (
        "dramatic high-fashion studio portrait photograph of {kw}, wearing a sleek all-black or monochrome editorial "
        "outfit — fitted black turtleneck, structured blazer, or minimalist couture styling, intense and commanding "
        "expression with strong eye contact radiating confidence and presence, set against a pure jet-black seamless "
        "background, cinematic chiaroscuro split lighting with a single powerful key light creating deep sculpted "
        "shadows on one side of the face and a sharp metallic rim light on the opposite edge for dramatic separation, "
        "subtle smoke or fog haze in background for atmosphere, 85mm lens at f/1.4, ultra-sharp focus on the eyes, "
        "skin tones deep and rich, high contrast black-and-white capable, editorial Vogue or Dazed magazine quality, "
        "award-winning portrait photography, 4K cinematic",
        "blurry, low quality, outdoor setting, colourful background, casual clothes, t-shirt, deformed face, "
        "bad anatomy, extra fingers, flat lighting, soft lighting, overexposed, amateur, watermark, text, smiling, "
        "cheerful, bright colours",
    ),
}

NEGATIVE_DEFAULT = "blurry, lowres, bad anatomy, bad hands, extra fingers, deformed, ugly, cartoon, anime, watermark, text"

# Flux1.dev base model ID in Astria gallery — all Flux LoRA inference routes through this
FLUX_BASE_TUNE_ID = 1504944


def _headers() -> dict:
    if not settings.astria_api_key:
        raise RuntimeError("ASTRIA_API_KEY is not set in environment")
    return {"Authorization": f"Bearer {settings.astria_api_key}"}


def _url(path: str) -> str:
    return f"{settings.astria_base_url}{path}"


# ── Tune (training) ────────────────────────────────────────────────────────────

def create_tune(title: str, image_urls: list[str], subject_keyword: str = "man", callback_url: str = "") -> dict:
    """
    Submit a fine-tuning job to Astria.

    Returns the full tune dict including `id` (integer).
    Training takes ~20 minutes (Flux) or ~5 minutes (SDXL).
    """
    if not image_urls:
        raise ValueError("At least one image URL is required to create a tune")

    is_flux = settings.astria_branch == "flux1"
    data = {
        "tune[title]": title,
        "tune[name]": subject_keyword,    # "man" | "woman" | "person"
        "tune[branch]": settings.astria_branch,
    }
    if is_flux:
        # Flux requires model_type=lora, a base_tune_id, and a portrait preset
        data["tune[model_type]"] = "lora"
        data["tune[base_tune_id]"] = str(FLUX_BASE_TUNE_ID)
        data["tune[preset]"] = "flux-lora-portrait"
    if callback_url:
        data["tune[callback]"] = callback_url
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

def create_prompts(tune_id: int, style_name: str, subject_keyword: str = "man", callback_url: str = "") -> dict:
    """
    Submit a generation prompt to an already-trained tune.

    Returns the prompt dict including `id`.
    Images fill in asynchronously — poll get_prompt() until `images` is non-empty.
    """
    trigger = f"sks {subject_keyword}" if settings.astria_branch == "flux1" else f"ohwx {subject_keyword}"
    style_key = style_name.lower().strip()
    positive, negative = STYLE_PROMPTS.get(style_key, (
        f"professional portrait of {trigger}, photorealistic, high quality",
        NEGATIVE_DEFAULT,
    ))
    positive = positive.replace("{kw}", trigger)

    is_flux = settings.astria_branch == "flux1"
    if is_flux:
        # Flux LoRA inference: reference the trained model inline and POST to base tune
        positive = f"<lora:{tune_id}:1> {positive}"
        endpoint_tune_id = FLUX_BASE_TUNE_ID
        prompt_body = {
            "text": positive,
            "num_images": settings.effective_images_per_job,
            "w": 768,
            "h": 1024,
            "steps": 28,
        }
    else:
        endpoint_tune_id = tune_id
        prompt_body = {
            "text": positive,
            "negative_prompt": negative,
            "num_images": settings.effective_images_per_job,
            "w": 768,
            "h": 1024,
            "steps": 30,
            "cfg_scale": 7.5,
        }
    if callback_url:
        prompt_body["callback"] = callback_url

    payload = {"prompt": prompt_body}
    logger.info("Creating Astria prompt for tune %s via endpoint tune %s | style=%s", tune_id, endpoint_tune_id, style_name)
    response = requests.post(
        _url(f"/tunes/{endpoint_tune_id}/prompts"),
        headers=_headers(),
        json=payload,
        timeout=30,
    )
    _raise_for_status(response)
    prompt = response.json()
    logger.info("Astria prompt created: id=%s", prompt["id"])
    return prompt


def get_prompt(tune_id: int, prompt_id: int) -> dict:
    """Fetch current prompt state. For Flux, prompts live under the base tune endpoint."""
    endpoint_tune_id = FLUX_BASE_TUNE_ID if settings.astria_branch == "flux1" else tune_id
    response = requests.get(
        _url(f"/tunes/{endpoint_tune_id}/prompts/{prompt_id}"),
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
