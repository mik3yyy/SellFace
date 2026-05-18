# Astria AI Integration

How SellFace uses Astria to train a personal LoRA model and generate styled headshots.

---

## Overview

Every user gets their own fine-tuned AI model (a LoRA) trained on their face photos. Once trained, that model is reused for every style they buy. There are no webhooks — the backend polls Astria on a timer using Celery's `self.retry(countdown=N)` pattern, which is non-blocking.

```
User uploads photos
       ↓
POST /generation-jobs  (iOS taps a style bundle)
       ↓
  ┌────────────────────────┐     ┌───────────────────────────────────┐
  │  training queue         │     │  generation queue                  │
  │  train_persona task     │     │  process_generation_job task       │
  │                         │     │                                    │
  │  1. Submit tune to      │     │  1. Wait for persona.status=ready  │
  │     Astria (flux1 LoRA) │     │  2. Submit prompt to Astria        │
  │  2. Poll every 60s      │     │  3. Poll every 30s                 │
  │  3. trained_at set?     │     │  4. images[] populated?            │
  │     → persona = ready   │     │     → download → Cloudinary        │
  └────────────────────────┘     │  5. Mark job completed             │
                                  │  6. Push notification → iOS        │
                                  └───────────────────────────────────┘
```

Both tasks run in parallel from the moment the user taps a style. The generation task just waits internally until training finishes.

---

## Stage 1 — Training (LoRA Fine-Tune)

**File:** `app/tasks/training.py` | **Celery queue:** `training`

### What triggers it

`POST /generation-jobs` in `app/routers/generation_jobs.py` (lines 68–73). If the persona has no `astria_tune_id` yet, it fires `train_persona.apply_async(args=[persona_id])`.

### What it does

**First call — submit tune:**
```python
astria_service.create_tune(
    title=persona.name,          # e.g. "Michael"
    image_urls=[...],            # Cloudinary URLs of the user's uploaded photos
    subject_keyword="man",       # or "woman" / "person"
)
```

Calls `POST https://api.astria.ai/tunes` with:

| Field | Value |
|---|---|
| `tune[title]` | Persona name |
| `tune[name]` | `"man"` / `"woman"` / `"person"` |
| `tune[branch]` | `flux1` |
| `tune[callback]` | `""` (no webhook) |
| `tune[image_urls][]` | Repeated — one per Cloudinary image URL |

Saves the returned integer `tune.id` → `persona.astria_tune_id`, marks persona `processing`, then reschedules itself in 60 seconds.

**Subsequent calls — poll:**
```python
tune = astria_service.get_tune(persona.astria_tune_id)
# GET https://api.astria.ai/tunes/{tune_id}
```

| Condition | Action |
|---|---|
| `tune["error"]` is set | Mark persona `failed`, stop |
| `tune["trained_at"]` is `None` | Still training → retry in 60s |
| `tune["trained_at"]` is set | Mark persona `ready`, stop |

**Limits:**
- Polls every **60 seconds**
- Max **90 retries** = 90 minutes total
- Timeout or billing errors (402, 401, 403, 422) → mark persona `failed` immediately, no more retries

### Training image cleanup

Once training is confirmed complete, the task immediately deletes every training photo from Cloudinary and nulls out `cloudinary_public_id` / `remote_url` on each `PersonaImage` row. The Astria LoRA already has the user's face baked in — we don't need the originals anymore. The `PersonaImage` rows themselves are kept so we retain the count of how many photos were submitted.

### How we know training is done

```python
# app/services/astria_service.py line 131
def is_tune_ready(tune: dict) -> bool:
    return tune.get("trained_at") is not None
```

Astria sets `trained_at` to a timestamp when the LoRA is fully trained. Until that field is present, we keep polling.

---

## Stage 2 — Generation (Image Creation)

**File:** `app/tasks/generation.py` | **Celery queue:** `generation`

### What triggers it

Same `POST /generation-jobs` call — fired immediately after the training task, but the generation task waits internally.

### Waiting for training

```python
if job.persona.status != PersonaStatus.ready:
    raise self.retry(countdown=60)   # check again in 60s
```

The generation task does nothing until `persona.status == ready`. It checks every 60 seconds, sharing the same MAX_RETRIES=150 budget that also covers the generation polling phase.

### Submitting the prompt

Once training is confirmed:

```python
astria_service.create_prompts(
    tune_id=job.persona.astria_tune_id,
    style_name=job.style_bundle.name,   # e.g. "professional"
    subject_keyword="man",
)
```

Calls `POST https://api.astria.ai/tunes/{tune_id}/prompts` with:

```json
{
  "prompt": {
    "text": "professional corporate headshot of ohwx man, tailored business suit...",
    "negative_prompt": "blurry, low quality, cartoon...",
    "num_images": 8,
    "w": 768,
    "h": 1024,
    "steps": 30,
    "cfg_scale": 7.5,
    "callback": ""
  }
}
```

The trigger word **`ohwx {subject}`** (e.g. `ohwx man`) is how Astria knows to apply this specific user's LoRA.

Saves the returned integer `prompt.id` → `job.astria_prompt_id`, reschedules itself in 30 seconds.

### Style → Prompt mapping

All 8 styles are defined in `app/services/astria_service.py` `STYLE_PROMPTS` dict (lines 22–70):

| Style ID | Positive prompt summary |
|---|---|
| `professional` | Business suit, white studio background, soft box lighting |
| `casual` | Park, golden hour, jeans and t-shirt |
| `executive` | Italian suit, boardroom, Rembrandt lighting |
| `creator` | Streetwear, ring light, vibrant background, Instagram aesthetic |
| `linkedin` | Business casual, light grey background, warm smile |
| `old money` | Tweed blazer, English estate, oil painting lighting |
| `sales` | Glass office, warm confident smile, approachable |
| `studio` | Chiaroscuro, pure black background, editorial magazine |

### Polling for images

```python
prompt = astria_service.get_prompt(tune_id, job.astria_prompt_id)
# GET https://api.astria.ai/tunes/{tune_id}/prompts/{prompt_id}

def are_images_ready(prompt: dict) -> bool:
    return bool(prompt.get("images"))
```

Astria populates `prompt["images"]` as an array of `{"url": "..."}` objects when generation completes. Until that array is non-empty, the task retries every 30 seconds.

### What happens when images arrive

1. Downloads each image URL from Astria CDN (`astria_service.download_image`)
2. Uploads bytes to Cloudinary at `sellface/generated/{persona_id}/{job_id}/`
3. If Cloudinary fails, falls back to direct Astria CDN URL (images aren't lost)
4. Creates a `GeneratedImage` row per image
5. Marks `job.status = completed`, sets `job.completed_at`

**Limits:**
- Polls every **30 seconds**
- Max **150 retries** total (covers both training-wait and generation-poll phases = ~75 minutes of generation headroom after training)

---

## Stage 3 — Push Notification

**File:** `app/services/notification_service.py`

Once the job is marked completed, the generation task immediately fires a push:

```python
tokens = [dt.token for dt in job.user.device_tokens if dt.is_active]
notification_service.send_images_ready(tokens, job.persona.name, job_id)
```

### APNs payload (success)

```json
{
  "aps": {
    "alert": {
      "title": "Your photos are ready!",
      "body": "Michael's generated images are ready to view."
    },
    "sound": "default",
    "badge": 1
  },
  "job_id": "<uuid>"
}
```

The `job_id` is included so the iOS app can navigate directly to the right results screen on tap.

### APNs payload (failure)

```json
{
  "aps": {
    "alert": {
      "title": "Generation failed",
      "body": "We couldn't generate Michael's images. Please try again."
    },
    "sound": "default"
  }
}
```

### How APNs auth works

Uses JWT (ES256) signed with the `.p8` key from App Store Connect. The JWT is cached for ~50 minutes (`_jwt_cache`) since APNs tokens are valid for 1 hour. Configured via env vars:

| Env var | What it is |
|---|---|
| `APNS_KEY_ID` | 10-character key ID from App Store Connect |
| `APNS_TEAM_ID` | Apple Developer team ID |
| `APNS_PRIVATE_KEY` | Full `.p8` contents with `\n` between lines |
| `APNS_BUNDLE_ID` | App bundle ID (e.g. `com.sellface.app`) |
| `APNS_USE_SANDBOX` | `true` for dev/TestFlight, `false` for prod |

If any of the first three are missing, notifications are skipped with a warning log — the job still completes.

---

## Full Status Flow

```
Persona:   draft → uploading → processing → ready → (stays ready forever)
Job:                                        queued → processing → completed / failed
```

```
iOS polls GET /generation-jobs/{job_id}
  job.status == "completed"  →  job.generated_images[].image_url  →  show results
  job.status == "failed"     →  show error + retry button
```

iOS also receives the APNs push with `job_id` — the results screen should handle both the polling path and the cold-launch-from-notification path.

---

## Environment Variables Required

| Variable | Where to set | Notes |
|---|---|---|
| `ASTRIA_API_KEY` | Render env | Bearer token from astria.ai dashboard |
| `CLOUDINARY_CLOUD_NAME` | Render env | |
| `CLOUDINARY_API_KEY` | Render env | |
| `CLOUDINARY_API_SECRET` | Render env | |
| `APNS_KEY_ID` | Render env | From App Store Connect |
| `APNS_TEAM_ID` | Render env | Apple Developer portal |
| `APNS_PRIVATE_KEY` | Render env | `.p8` contents, `\n` for line breaks |
| `APNS_BUNDLE_ID` | Render env | e.g. `com.sellface.app` |
| `REDIS_URL` | Render env | Celery broker + result backend |
